# frozen_string_literal: true

require "csv"

# Imports stories from a WordPress "Posts Export" CSV (stories.awbw.org).
#
# For EVERY row we create a StoryIdea (the canonical submission record). For
# rows that were published/public on WordPress (Status == "publish") we ALSO
# create a published Story connected back to that idea via story_idea_id —
# mirroring the in-app flow where staff promote an idea into a published story.
#
# This importer deliberately requires NO schema changes. Fields that have no
# home in the current model (original WordPress publish date, the source
# permalink / post ID, the free-text US state, the free-text facilitator) are
# logged as warnings rather than dropped silently. See the importer notes in
# the PR / .context for the recommended (optional) columns that would let us
# preserve them.
class StoryImporter
  Result = Struct.new(
    :rows_processed, :ideas_created, :stories_created, :skipped, :warnings,
    keyword_init: true
  ) do
    def summary
      [
        "rows processed: #{rows_processed}",
        "story ideas created: #{ideas_created}",
        "connected stories created: #{stories_created}",
        "skipped: #{skipped.size}",
        "warnings: #{warnings.size}"
      ].join("\n")
    end
  end

  # WordPress "publish" status means the post was live and public.
  PUBLISHED_WP_STATUS = "publish"

  # WordPress "Categories" value → portal Sector name. Sourced from the AWBW
  # "Story Share to Portal Migration" mapping and kept in a data file so staff
  # can maintain it without touching Ruby. Keys are the human-readable WordPress
  # spelling; lookups are case-insensitive. Categories with no entry (e.g.
  # "Facilitator Spotlights") are logged as warnings rather than guessed at.
  SECTOR_MAP_PATH = Rails.root.join("config/story_import_sector_mapping.yml").freeze
  SECTOR_BY_CATEGORY = YAML.load_file(SECTOR_MAP_PATH)
    .fetch("category_to_sector")
    .transform_keys(&:downcase)
    .freeze

  # WordPress "showhide_the_name" → our author_credit_preference enum.
  AUTHOR_CREDIT_BY_SHOWHIDE = {
    "display_full_name" => "full_name",
    "display_first_name" => "first_name_only",
    "hide_full_name" => "anonymous"
  }.freeze
  DEFAULT_AUTHOR_CREDIT = "full_name"

  # WordPress audience "Tags" → our WindowsType short_name.
  CHILD_AUDIENCE = %w[children teens].freeze
  COMBINED_AUDIENCE = %w[families].freeze
  DEFAULT_WINDOWS_TYPE = "Adult"

  # Flags across the various WordPress "featured" custom fields.
  FEATURED_FLAGS = %w[
    home_top_featured_story home_bottom_featured_story
    new_home_top_featured new_home_bottom_featured mark_as_featured
  ].freeze

  def initialize(csv_path:, import_user:, organization_status: nil, dry_run: false, logger: nil)
    @csv_path = csv_path
    @import_user = import_user
    @organization_status = organization_status || default_organization_status
    @dry_run = dry_run
    @logger = logger || Rails.logger
    @result = Result.new(
      rows_processed: 0, ideas_created: 0, stories_created: 0, skipped: [], warnings: []
    )
    @organization_cache = {}
    @windows_type_cache = {}
  end

  def call
    raise ArgumentError, "import_user is required" if @import_user.nil?
    raise ArgumentError, "no OrganizationStatus available" if @organization_status.nil?

    CSV.foreach(@csv_path, headers: true, encoding: "bom|utf-8") do |row|
      @result.rows_processed += 1
      begin
        import_row(row)
      rescue => e
        record_skip(row, "#{e.class}: #{e.message}")
        @logger.error("[StoryImporter] row #{wp_id(row)}: #{e.class} - #{e.message}")
      end
    end
    @result
  end

  private

  attr_reader :result

  def import_row(row)
    title = clean(row["Title"])
    return record_skip(row, "blank title") if title.blank?

    organization = find_or_create_organization(row)
    windows_type = windows_type_for(row)
    note_unmapped_fields(row)

    idea = build_idea(row, title:, organization:, windows_type:)
    return record_skip(row, "story idea already exists for this org/title") if duplicate_idea?(idea)

    # Resolve the Sector once per row (warns even on a dry run so the preview
    # reflects real tagging coverage), then apply it to both records.
    sector = sector_for(row)

    return unless persist(idea)
    tag_sector(idea, sector)
    @result.ideas_created += 1

    return unless published?(row)
    create_connected_story(row, idea:, title:, organization:, windows_type:, sector:)
  end

  def create_connected_story(row, idea:, title:, organization:, windows_type:, sector:)
    if Story.where("LOWER(title) = ?", title.downcase).exists?
      return record_warning(row, "published story skipped — title already taken: #{title.inspect}")
    end

    featured = FEATURED_FLAGS.any? { |flag| truthy?(row[flag]) }
    story = Story.new(
      story_idea: idea,
      title: title,
      rhino_body: body_html(row, title),
      organization: organization,
      windows_type: windows_type,
      external_workshop_title: clean(row["story_workshop_name"]),
      youtube_url: youtube_url(row),
      author_credit_preference: author_credit(row),
      permission_given: true,
      published: true,
      publicly_visible: true,
      featured: featured,
      publicly_featured: featured,
      created_by: @import_user,
      updated_by: @import_user
    )
    return unless persist(story)
    tag_sector(story, sector)
    @result.stories_created += 1
  end

  def build_idea(row, title:, organization:, windows_type:)
    StoryIdea.new(
      title: title,
      rhino_body: body_html(row, title),
      organization: organization,
      windows_type: windows_type,
      external_workshop_title: clean(row["story_workshop_name"]),
      youtube_url: youtube_url(row),
      author_credit_preference: author_credit(row),
      permission_given: true,
      created_by: @import_user,
      updated_by: @import_user
    )
  end

  def duplicate_idea?(idea)
    StoryIdea.where(organization_id: idea.organization_id)
             .where("LOWER(title) = ?", idea.title.downcase)
             .exists?
  end

  # Resolve the row's WordPress category to an existing Sector via the mapping.
  # Unmatched values are surfaced as warnings (never invented), once per row —
  # including on a dry run so the preview reflects real tagging coverage.
  def sector_for(row)
    name = clean(row["Categories"])
    return if name.blank? || name.casecmp?("uncategorized")

    sector_name = SECTOR_BY_CATEGORY[name.downcase] || name
    sector = Sector.where("LOWER(name) = ?", sector_name.downcase).first
    record_warning(row, "no Sector match for category #{name.inspect}") unless sector
    sector
  end

  # Persist the tag only for a saved record on a real run; a dry run resolves and
  # warns above but writes nothing.
  def tag_sector(record, sector)
    return if sector.nil? || @dry_run || record.new_record?
    record.sectors |= [ sector ]
  end

  def find_or_create_organization(row)
    name = clean(row["organization_name"]).presence || "Unknown organization"
    @organization_cache[name.downcase] ||=
      Organization.where("LOWER(name) = ?", name.downcase).first ||
      create_organization(name)
  end

  def create_organization(name)
    return Organization.new(name: name, organization_status: @organization_status) if @dry_run
    Organization.create!(name: name, organization_status: @organization_status)
  end

  def windows_type_for(row)
    audiences = clean(row["Tags"]).to_s.downcase.split(/[|,]/).map(&:strip)
    short_name =
      if audiences.intersect?(COMBINED_AUDIENCE) ||
         (audiences.intersect?(CHILD_AUDIENCE) && (audiences - CHILD_AUDIENCE).any?)
        "Combined"
      elsif audiences.intersect?(CHILD_AUDIENCE)
        "Children"
      else
        DEFAULT_WINDOWS_TYPE
      end
    @windows_type_cache[short_name] ||= WindowsType.find_by!(short_name: short_name)
  end

  # Records that have no home in the current schema — logged, not dropped.
  def note_unmapped_fields(row)
    state = clean(row["state"])
    record_warning(row, "unmapped state #{state.inspect}") if state.present?

    facilitator = [ clean(row["facilitator_name"]), clean(row["facilitator_last_name"]) ]
                  .compact_blank.join(" ")
    record_warning(row, "unmapped facilitator #{facilitator.inspect}") if facilitator.present?

    date = clean(row["Date"])
    record_warning(row, "unmapped original publish date #{date.inspect}") if date.present?
  end

  def body_html(row, title)
    clean_html(row["Content"]).presence ||
      clean_html(row["Excerpt"]).presence ||
      "<p>#{ERB::Util.html_escape(title)}</p>"
  end

  def youtube_url(row)
    (clean(row["story_youtube_url"]).presence || clean(row["story_youtube_ur"]).presence)
  end

  def author_credit(row)
    AUTHOR_CREDIT_BY_SHOWHIDE[clean(row["showhide_the_name"])] || DEFAULT_AUTHOR_CREDIT
  end

  def published?(row)
    clean(row["Status"]).casecmp?(PUBLISHED_WP_STATUS)
  end

  def persist(record)
    return true if @dry_run
    record.save!
    true
  rescue ActiveRecord::RecordInvalid => e
    @logger.error("[StoryImporter] invalid #{record.class}: #{e.message}")
    false
  end

  def default_organization_status
    OrganizationStatus.find_by(name: "Pending") || OrganizationStatus.first
  end

  def wp_id(row)
    clean(row["ID"]).presence || "?"
  end

  def truthy?(value)
    %w[1 true yes].include?(clean(value).to_s.downcase)
  end

  # WordPress export encodes entities (e.g. &amp;) even in plain-text columns.
  def clean(value)
    CGI.unescapeHTML(value.to_s).strip
  end

  # Content columns are already HTML; only decode double-encoded entities.
  def clean_html(value)
    value.to_s.strip
  end

  def record_skip(row, reason)
    @result.skipped << "row #{wp_id(row)} (#{clean(row['Title'])}): #{reason}"
    nil
  end

  def record_warning(row, reason)
    @result.warnings << "row #{wp_id(row)} (#{clean(row['Title'])}): #{reason}"
    nil
  end
end
