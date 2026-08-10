# frozen_string_literal: true

require "csv"

# Imports stories from a WordPress "Posts Export" CSV (stories.awbw.org).
#
# EVERY row becomes a Story (published per the WordPress Status). A story whose
# author is a non-AWBW person (a facilitator, not an admin/super_user) also gets
# a StoryIdea — the submission record — promoted into it, mirroring the in-app
# idea→story flow; AWBW-authored or author-less rows are Story-only.
#
# The author comes from the facilitator name; when it can't form a Person (a
# single name, or "AWBW"), the name is kept as a Comment instead. An anonymous
# credit flags the author's anonymous_contributions profile setting. Content is
# run through wpautop so the export's raw-newline paragraphs survive as HTML, and
# the original publish Date is preserved as created_at.
class StoryImporter
  Result = Struct.new(
    :rows_processed, :ideas_created, :stories_created, :skipped, :warnings, :previews,
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

  # A row-level summary of what the import would do, for the preview interstitial:
  # the row's shorthand, the existing records it matches, and the new/updated
  # records (incl. the sectorable_items / categorizable_items it would tag).
  RowPreview = Struct.new(
    :wp_id, :title, :will_publish, :skipped_reason,
    :organization, :organization_new, :author_label, :author_new, :author_updated,
    :creates_story, :creates_idea, :workshop_label, :sectors, :categories, :comment, :warnings,
    keyword_init: true
  )

  # WordPress "publish" status means the post was live and public.
  PUBLISHED_WP_STATUS = "publish"

  # WordPress export value → portal taxonomy tags. Sourced from the AWBW "Story
  # Share to Portal Migration" mapping and kept in a data file so staff can
  # maintain it without touching Ruby. Keys are the human-readable WordPress
  # spelling; lookups are case-insensitive. See the YAML header for the shape.
  SECTOR_MAP_PATH = Rails.root.join("config/story_import_sector_mapping.yml").freeze
  TRANSLATIONS = YAML.load_file(SECTOR_MAP_PATH)
    .fetch("translations")
    .transform_keys(&:downcase)
    .freeze

  # Columns whose values we translate into portal tags. Categories / User
  # Categories carry Sector + topic tags; Tags and who_is_your_story_about carry
  # the audience (age range + story population). Values are split on "|" or ","
  # and de-duplicated case-insensitively across all columns.
  TRANSLATION_COLUMNS = [ "Categories", "User Categories", "Tags", "who_is_your_story_about" ].freeze

  # Audience "Tags" that mark the story's author as a recipient of a named Grant's
  # scholarship (story → author → scholarship → grant).
  GRANT_BY_TAG = YAML.load_file(SECTOR_MAP_PATH)
    .fetch("grant_tags", {})
    .transform_keys(&:downcase)
    .freeze

  # WordPress organization_name → how to resolve the Organization. "" keeps the
  # name, "Other Name" is a spelling variant to map, "SKIP" means no org/affiliation.
  ORG_MAP_PATH = Rails.root.join("config/story_import_organization_mapping.yml").freeze
  ORG_BY_NAME = (YAML.load_file(ORG_MAP_PATH)["organization_mapping"] || {})
    .transform_keys(&:downcase)
    .freeze

  # Story author_credit_preference → the author's profile display_name_preference.
  # "anonymous" has no profile equivalent, so it is left off (never synced).
  DISPLAY_PREF_BY_CREDIT = {
    "full_name" => "full_name",
    "first_name_only" => "first_name_only"
  }.freeze

  # Resolved tags for one row, applied to both the idea and its connected story.
  RowTags = Struct.new(:sectors, :categories, keyword_init: true)

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
      rows_processed: 0, ideas_created: 0, stories_created: 0, skipped: [], warnings: [], previews: []
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
    warnings_before = @result.warnings.size
    preview = RowPreview.new(
      wp_id: wp_id(row), title: clean(row["Title"]), will_publish: published?(row),
      sectors: [], categories: [], warnings: []
    )
    @result.previews << preview

    title = preview.title
    if title.blank?
      record_skip(row, "blank title")
      preview.skipped_reason = "blank title"
      return
    end
    if Story.where("LOWER(title) = ?", title.downcase).exists?
      record_skip(row, "story already exists for title #{title.inspect}")
      preview.skipped_reason = "story already exists"
      return
    end

    organization = resolve_organization(row)
    windows_type = windows_type_for(row)
    author = resolve_author(row)
    tags = resolve_tags(row)
    content = body_html(row, title)
    workshop, external_title = workshop_for(row)
    describe_row(preview, row, organization, author, tags, workshop, external_title, warnings_before)

    # Every row becomes a Story. A non-AWBW author's story also gets a StoryIdea
    # (the submission record) promoted into it; AWBW-authored rows are Story-only.
    idea = nil
    if preview.creates_idea
      idea = build_idea(row, title:, organization:, windows_type:, content:, workshop:, external_title:)
      return unless persist(idea)
      apply_tags(idea, tags)
      @result.ideas_created += 1
    end

    story = build_story(row, idea:, title:, organization:, windows_type:, author:, content:, workshop:, external_title:)
    return unless persist(story)
    apply_tags(story, tags)
    finalize_story(row, story, idea, author, organization)
    @result.stories_created += 1
  end

  # Fill the preview with what the row resolved to (matched vs new records + the
  # tags it would create), for the interstitial.
  def describe_row(preview, row, organization, author, tags, workshop, external_title, warnings_before)
    preview.organization = organization&.name
    preview.organization_new = organization&.new_record? || false
    preview.author_label = author_label(row, author)
    preview.author_new = author&.new_record? || false
    preview.author_updated = author&.persisted? && DISPLAY_PREF_BY_CREDIT.key?(author_credit(row))
    preview.creates_story = true
    preview.creates_idea = from_non_awbw?(author) && organization.present?
    preview.workshop_label =
      if workshop then "Matched workshop: #{workshop.title}"
      elsif external_title.present? then "External title: #{external_title}"
      end
    preview.sectors = tags.sectors.map(&:name)
    preview.categories = tags.categories.map { |c| "#{c.category_type.name}: #{c.decorate.display_name}" }
    preview.comment = author ? nil : facilitator_display(row).presence
    preview.warnings = @result.warnings.drop(warnings_before).map { |w| w.sub(/\Arow \S+ \(.*?\): /, "") }
  end

  def author_label(row, author)
    return "#{author.first_name} #{author.last_name}" if author
    name = facilitator_display(row)
    name.present? ? "#{name} (unmatched → comment)" : "none (assumed AWBW)"
  end

  # Post-save side effects for a persisted story (skipped on a dry run).
  def finalize_story(row, story, idea, author, organization)
    return if @dry_run

    comment_facilitator(row, story, idea, author)
    link_grant_scholarship(row, story, author)
    create_facilitator_affiliation(author, organization)
    sync_author_profile(author, row)
  end

  def build_story(row, idea:, title:, organization:, windows_type:, author:, content:, workshop:, external_title:)
    featured = FEATURED_FLAGS.any? { |flag| truthy?(row[flag]) }
    published = published?(row)
    story = Story.new(
      story_idea: idea,
      title: title,
      rhino_body: content,
      organization: organization,
      windows_type: windows_type,
      author: author&.persisted? ? author : nil,
      workshop: workshop,
      external_workshop_title: external_title,
      youtube_url: youtube_url(row),
      author_credit_preference: author_credit(row),
      permission_given: true,
      published: published,
      publicly_visible: published,
      featured: featured,
      publicly_featured: featured,
      created_by: @import_user,
      updated_by: @import_user
    )
    story.created_at = original_created_at(row) || story.created_at
    story
  end

  # Connect a grant-tagged story to its Grant through the author's Scholarship
  # (story → author → scholarship → grant). Needs a resolved author (a Person).
  def link_grant_scholarship(row, story, author)
    grant_names = grant_names_for(row)
    return if grant_names.empty?
    return record_warning(row, "grant tag present but author unresolved (needs first + last name)") unless author&.persisted?

    grant_names.each do |grant_name|
      grant = Grant.where("LOWER(name) = ?", grant_name.downcase).first
      next record_warning(row, "no Grant match for #{grant_name.inspect}") unless grant
      Scholarship.find_or_create_by!(recipient: author, grant: grant)
    end
  end

  def grant_names_for(row)
    clean(row["Tags"]).split(/[|,]/).map(&:strip).filter_map { |tag| GRANT_BY_TAG[tag.downcase] }
  end

  # Find or build the story's author Person from the facilitator name. A Person
  # requires both names, so a single-name facilitator (e.g. "Teena") can't resolve.
  # On a dry run an unseen author is returned unsaved so the preview reflects
  # whether a StoryIdea would also be created (non-AWBW authors only).
  def resolve_author(row)
    first = clean(row["facilitator_name"])
    last = clean(row["facilitator_last_name"])
    return if first.blank? || last.blank?

    email = clean(row["facilitator_email"]).presence
    person = email && Person.where("LOWER(email) = ?", email.downcase).first
    person ||= Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?", first.downcase, last.downcase).first
    return person if person

    attrs = { first_name: first, last_name: last, email: email }
    @dry_run ? Person.new(attrs) : Person.create!(attrs)
  end

  # A story is treated as a facilitator submission (gets a StoryIdea) when it has
  # a resolved author who is not AWBW staff. No author → assumed AWBW → Story-only.
  def from_non_awbw?(author)
    author.present? && !author.user&.super_user?
  end

  def build_idea(row, title:, organization:, windows_type:, content:, workshop:, external_title:)
    idea = StoryIdea.new(
      title: title,
      rhino_body: content,
      organization: organization,
      windows_type: windows_type,
      workshop: workshop,
      external_workshop_title: external_title,
      youtube_url: youtube_url(row),
      author_credit_preference: author_credit(row),
      permission_given: true,
      created_by: @import_user,
      updated_by: @import_user
    )
    idea.created_at = original_created_at(row) || idea.created_at
    idea
  end

  # Resolve the Organization via the mapping file: "SKIP" → none; a variant name
  # → the mapped org; otherwise the WordPress name as-is. Blank → "Unknown".
  def resolve_organization(row)
    raw = clean(row["organization_name"])
    return find_or_create_organization("Unknown organization") if raw.blank?

    mapped = ORG_BY_NAME[raw.downcase]
    return nil if mapped == "SKIP"
    find_or_create_organization(mapped.presence || raw)
  end

  # Exact-title match links the story to an existing Workshop; otherwise the
  # free-text title is kept as external_workshop_title. Returns [ workshop, title ].
  def workshop_for(row)
    title = clean(row["story_workshop_name"])
    return [ nil, nil ] if title.blank?

    workshop = Workshop.where("LOWER(title) = ?", title.downcase).first
    workshop ? [ workshop, nil ] : [ nil, title ]
  end

  def original_created_at(row)
    date = clean(row["Date"])
    return if date.blank?
    Time.zone.parse(date)
  rescue ArgumentError
    nil
  end

  # Preserve a facilitator name that couldn't become an author (single name,
  # "AWBW") as a Comment on the story (and its idea) so it isn't lost.
  def comment_facilitator(row, story, idea, author)
    return if author
    name = facilitator_display(row)
    return if name.blank?

    [ story, idea ].compact.each do |record|
      Comment.create!(commentable: record, body: "Imported facilitator: #{name}", created_by: @import_user)
    end
  end

  # Facilitator affiliations connect a non-AWBW author to their organization.
  def create_facilitator_affiliation(author, organization)
    return unless from_non_awbw?(author) && author.persisted? && organization
    return if Affiliation.exists?(person: author, organization: organization, title: Affiliation::FACILITATOR_TITLE)

    Affiliation.create!(person: author, organization: organization, title: Affiliation::FACILITATOR_TITLE)
  end

  # Reflect the story's credit on the author's profile. An anonymous credit flags
  # anonymous_contributions and leaves the display preference at its full_name
  # default; otherwise the display preference is synced, but only when it is still
  # the default (full_name) — a deliberate choice is honored.
  def sync_author_profile(author, row)
    return unless author&.persisted?

    if author_credit(row) == "anonymous"
      author.update!(anonymous_contributions: true) unless author.anonymous_contributions?
      return
    end

    pref = DISPLAY_PREF_BY_CREDIT[author_credit(row)]
    return if pref.nil? || (author.display_name_preference.present? && author.display_name_preference != "full_name")

    author.update!(display_name_preference: pref)
  end

  def facilitator_display(row)
    [ clean(row["facilitator_name"]), clean(row["facilitator_last_name"]) ].compact_blank.join(" ")
  end

  # Translate a row's WordPress values (Categories, User Categories, audience
  # Tags) into portal Sectors and Categories via the mapping file. Unmatched
  # values are surfaced as warnings (never invented), once per row — including on
  # a dry run so the preview reflects real tagging coverage.
  def resolve_tags(row)
    sectors = []
    categories = []
    translation_sources(row).each do |source|
      targets = TRANSLATIONS[source.downcase]
      if targets.nil?
        record_warning(row, "no translation for #{source.inspect}")
        next
      end
      targets.each { |target| resolve_target(row, source, target, sectors, categories) }
    end
    RowTags.new(sectors: sectors.uniq, categories: categories.uniq)
  end

  def resolve_target(row, source, target, sectors, categories)
    if (name = target["sector"])
      sector = Sector.where("LOWER(name) = ?", name.downcase).first
      sector ? sectors << sector : record_warning(row, "no Sector match for #{source.inspect} → #{name.inspect}")
    elsif (name = target["category"])
      category = category_named(name, target["type"])
      category ? categories << category : record_warning(row, "no Category match for #{source.inspect} → #{name.inspect} (#{target['type']})")
    end
  end

  def category_named(name, type)
    scope = Category.where("LOWER(categories.name) = ?", name.downcase)
    scope = scope.joins(:category_type).where(category_types: { name: type }) if type.present?
    scope.first
  end

  # Distinct WordPress source values across the translation columns, de-duplicated
  # case-insensitively (Categories and User Categories overlap heavily).
  def translation_sources(row)
    TRANSLATION_COLUMNS
      .flat_map { |column| clean(row[column]).split(/[|,]/).map(&:strip) }
      .reject(&:blank?)
      .uniq(&:downcase)
  end

  # Persist tags only for a saved record on a real run; a dry run resolves and
  # warns above but writes nothing.
  def apply_tags(record, tags)
    return if @dry_run || record.new_record?
    record.sectors |= tags.sectors if tags.sectors.any?
    record.categories |= tags.categories if tags.categories.any?
  end

  def find_or_create_organization(name)
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

  def body_html(row, title)
    wpautop(clean_html(row["Content"])).presence ||
      wpautop(clean_html(row["Excerpt"])).presence ||
      "<p>#{ERB::Util.html_escape(title)}</p>"
  end

  # The export's editor content uses raw newlines (\r\n) for paragraph breaks
  # rather than <p>/<br>, which HTML collapses. Mimic WordPress's wpautop: blank
  # lines become paragraphs and remaining single newlines become <br>. Content
  # that already carries <p> tags is left untouched.
  def wpautop(text)
    normalized = text.to_s.gsub(/\r\n?/, "\n").strip
    return "" if normalized.blank?
    return normalized if normalized.match?(/<p[\s>]/i)

    normalized.split(/\n{2,}/).map { |para| "<p>#{para.strip.gsub("\n", "<br>")}</p>" }.join
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
