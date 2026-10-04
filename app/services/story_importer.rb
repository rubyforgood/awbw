# frozen_string_literal: true

require "csv"
require "set"

# Imports stories from the curated stories spreadsheet — the columns this
# importer's own dry-run preview produces, reviewed and edited by staff and then
# re-uploaded.
#
# EVERY importable row becomes a Story; a StoryIdea (the submission record) is
# promoted into it only when the "status" column says "story idea" (and an
# organization exists for it to belong to). The "status" column also sets the
# publish state ("Published story" vs "Draft story"). A "Skipped — reason" flag
# in either "import_action" or "status" drops the row. Column headers may be the
# curated sheet's human labels (see COLUMN_ALIASES) or the snake_case keys.
#
# The taxonomy is trusted as written: the sheet already carries resolved portal
# "sectors", "categories" (as "Type: Name") and "window_type" values, so they are
# looked up by name. Anything that can't be matched is preserved as a Comment on
# the story rather than invented. Content is run through wpautop so raw-newline
# paragraphs survive as HTML, and the publish date is preserved as created_at.
class StoryImporter
  # Columns the importer reads, in a natural order, for the downloadable template.
  TEMPLATE_HEADERS = %w[
    row_source row_number title import_action status wp_id content published published_date
    organization_name organization_status facilitator_name facilitator_last_name
    facilitator_email author_note name_display anonymous
    co_facilitator_name co_facilitator_last_name co_facilitator_email co_name_display co_anonymous
    workshop sectors window_type categories grants professional_licenses
    image_count image_urls image_alt_titles youtube_url featured
  ].freeze

  # The curated review sheet carries human-readable column labels; map each to
  # the snake_case key the importer reads so a sheet exported with either naming
  # imports identically. Matched case-insensitively on the trimmed label;
  # snake_case headers (and anything unlisted) pass through unchanged.
  COLUMN_ALIASES = {
    "title" => "title",
    "status" => "status",
    "wp id" => "wp_id",
    "content" => "content",
    "published" => "published",
    "publish date" => "published_date",
    "organization" => "organization_name",
    "org status" => "organization_status",
    "first name" => "facilitator_name",
    "last name" => "facilitator_last_name",
    "author email" => "facilitator_email",
    "author note" => "author_note",
    "name display" => "name_display",
    "anonymous credit?" => "anonymous",
    "coauthor first name" => "co_facilitator_name",
    "coauthor last name" => "co_facilitator_last_name",
    "coauthor email" => "co_facilitator_email",
    "coauthor name display" => "co_name_display",
    "workshop" => "workshop",
    "sectors" => "sectors",
    "window type" => "window_type",
    "categories" => "categories",
    "grant(s)" => "grants",
    "professional licenses" => "professional_licenses",
    "professional license(s)" => "professional_licenses",
    "images" => "image_count",
    "image urls" => "image_urls",
    "image alt/title" => "image_alt_titles",
    "youtube" => "youtube_url",
    "featured" => "featured"
  }.freeze

  HEADER_CONVERTER = lambda do |header|
    COLUMN_ALIASES.fetch(header.to_s.strip.downcase.gsub(/\s+/, " "), header)
  end

  # The spreadsheet columns for each credited author. A story can carry a first
  # author and an optional second (co-author), each with its own name/credit.
  AUTHOR_COLUMNS = {
    name: "facilitator_name", last: "facilitator_last_name", email: "facilitator_email",
    display: "name_display", anonymous: "anonymous"
  }.freeze
  CO_AUTHOR_COLUMNS = {
    name: "co_facilitator_name", last: "co_facilitator_last_name", email: "co_facilitator_email",
    display: "co_name_display", anonymous: "co_anonymous"
  }.freeze

  Result = Struct.new(
    :rows_processed, :ideas_created, :stories_created, :images_enqueued, :skipped, :warnings, :previews,
    keyword_init: true
  ) do
    def summary
      [
        "rows processed: #{rows_processed}",
        "story ideas created: #{ideas_created}",
        "connected stories created: #{stories_created}",
        "images queued: #{images_enqueued}",
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
    :creates_story, :creates_idea, :workshop_label, :sectors, :categories, :images, :comment, :warnings,
    keyword_init: true
  )

  # An import_action value the preview flagged as skipped (e.g. "Skipped — blank title").
  SKIP_ACTION = "Skipped"

  # A facilitator first name that means AWBW staff authored it — credit no Person.
  AWBW_NAME = "AWBW"

  # Story author_credit_preference → the author's profile display_name_preference.
  # "anonymous" has no profile equivalent, so it is left off (never synced).
  DISPLAY_PREF_BY_CREDIT = {
    "full_name" => "full_name",
    "first_name_only" => "first_name_only",
    "first_name_last_initial" => "first_name_last_initial"
  }.freeze

  # Resolved tags for one row, applied to both the idea and its connected story,
  # plus the names that matched nothing (preserved as comments on the story).
  RowTags = Struct.new(:sectors, :categories, :missing_sectors, :missing_categories, keyword_init: true)

  # Sheet "name_display" → our author_credit_preference. An "anonymous" value in
  # the separate "anonymous" column overrides this.
  AUTHOR_CREDIT_BY_DISPLAY = {
    "full name" => "full_name",
    "first name only" => "first_name_only",
    "first name + last initial" => "first_name_last_initial"
  }.freeze
  DEFAULT_AUTHOR_CREDIT = "full_name"

  def initialize(csv_path:, import_user:, organization_status: nil, dry_run: false, logger: nil)
    @csv_path = csv_path
    @import_user = import_user
    @organization_status = organization_status || default_organization_status
    @dry_run = dry_run
    @logger = logger || Rails.logger
    @result = Result.new(
      rows_processed: 0, ideas_created: 0, stories_created: 0, images_enqueued: 0,
      skipped: [], warnings: [], previews: []
    )
    @organization_cache = {}
    @windows_type_cache = {}
    @conflicting_authors = Set.new
  end

  def call
    raise ArgumentError, "import_user is required" if @import_user.nil?
    raise ArgumentError, "no OrganizationStatus available" if @organization_status.nil?

    @conflicting_authors = scan_conflicting_authors
    CSV.foreach(@csv_path, headers: true, header_converters: HEADER_CONVERTER, encoding: "bom|utf-8") do |row|
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
    return record_skip(row, "duplicate header row") if header_echo?(row)

    warnings_before = @result.warnings.size
    raw_title = title_text(row)
    preview = RowPreview.new(
      wp_id: wp_id(row), title: raw_title, will_publish: published?(row),
      sectors: [], categories: [], images: 0, warnings: []
    )
    @result.previews << preview

    if raw_title.blank?
      record_skip(row, "blank title")
      preview.skipped_reason = "blank title"
      return
    end
    if skipped_action?(row)
      reason = skip_reason(row)
      record_skip(row, reason)
      preview.skipped_reason = reason
      return
    end

    windows_type = windows_type_for(row)
    unless windows_type
      reason = "unknown window type #{clean(row['window_type']).inspect}"
      record_skip(row, reason)
      preview.skipped_reason = reason
      return
    end

    # A repeat title becomes a distinct "[COPY N] …" story rather than being skipped.
    title = unique_title(raw_title)
    preview.title = title

    organization = resolve_organization(row)
    if status_text(row).include?("story idea") && organization.nil?
      record_warning(row, "status requests a story idea but the row has no organization — imported as story only")
    end
    author = resolve_person(row, AUTHOR_COLUMNS)
    co_author = resolve_co_author(row, author)
    tags = resolve_tags(row)
    content = body_html(row, title)
    workshop, external_title = workshop_for(row)
    describe_row(preview, row, organization, author, co_author, tags, workshop, external_title, warnings_before)

    # Sync each profile first so the records snapshot the authors' resolved credit
    # (incl. anonymity) at build time rather than drifting from it.
    sync_author_profile(author, row, AUTHOR_COLUMNS)
    sync_author_profile(co_author, row, CO_AUTHOR_COLUMNS)

    credit = story_credit(row, AUTHOR_COLUMNS)
    co_credit = story_credit(row, CO_AUTHOR_COLUMNS)

    # Every importable row becomes a Story with a StoryIdea promoted into it. A
    # StoryIdea requires an organization, so an org-less row is Story-only.
    idea = nil
    if preview.creates_idea
      idea = build_idea(row, title:, organization:, windows_type:, author:, co_author:, content:, workshop:, external_title:, credit:, co_credit:)
      return unless persist(idea)
      nullify_blank_credit(idea, :author_credit_preference, credit)
      nullify_blank_credit(idea, :co_author_credit_preference, co_credit)
      apply_tags(idea, tags)
      @result.ideas_created += 1
    end

    story = build_story(row, idea:, title:, organization:, windows_type:, author:, co_author:, content:, workshop:, external_title:, credit:, co_credit:)
    return unless persist(story)
    nullify_blank_credit(story, :author_credit_preference, credit)
    nullify_blank_credit(story, :co_author_credit_preference, co_credit)
    apply_tags(story, tags)
    finalize_story(row, story, idea, author, co_author, organization, tags)
    @result.stories_created += 1

    import_images(row, story, preview)
  end

  # Story images come from the "image_urls" column (pipe-separated; the first is
  # the featured image → PrimaryAsset, the rest → GalleryAssets), each paired with
  # the matching entry in "image_alt_titles". Downloading them inline would blow the
  # request timeout, so we defer to a background job — counted in the preview but
  # only enqueued on a real run.
  def import_images(row, story, preview)
    urls = image_urls(row)
    count = urls.count(&:present?)
    preview.images = count
    return if @dry_run || count.zero?

    StoryAssetImportJob.perform_later(story, urls, titles: image_titles(row))
    @result.images_enqueued += count
  end

  # Kept parallel to image_titles (same split, no reject) so titles line up with
  # their image by position.
  def image_urls(row)
    clean(row["image_urls"]).split("|").map(&:strip)
  end

  def image_titles(row)
    clean(row["image_alt_titles"]).split("|").map(&:strip)
  end

  # Fill the preview with what the row resolved to (matched vs new records + the
  # tags it would create), for the interstitial.
  def describe_row(preview, row, organization, author, co_author, tags, workshop, external_title, warnings_before)
    preview.organization = organization&.name
    preview.organization_new = organization&.new_record? || false
    preview.author_label = author_label(row, author, co_author)
    preview.author_new = author&.new_record? || false
    preview.author_updated = author&.persisted? && DISPLAY_PREF_BY_CREDIT.key?(credit_for(row, AUTHOR_COLUMNS))
    preview.creates_story = true
    preview.creates_idea = creates_story_idea?(row, organization)
    preview.workshop_label =
      if workshop then "Matched workshop: #{workshop.title}"
      elsif external_title.present? then "External title: #{external_title}"
      end
    preview.sectors = tags.sectors.map(&:name)
    preview.categories = tags.categories.map { |c| "#{c.category_type.name}: #{c.decorate.display_name}" }
    preview.comment = author ? nil : person_display(row, AUTHOR_COLUMNS).presence
    preview.warnings = @result.warnings.drop(warnings_before).map { |w| w.sub(/\Arow \S+ \(.*?\): /, "") }
  end

  def author_label(row, author, co_author)
    label = single_author_label(row, author, AUTHOR_COLUMNS)
    return label unless co_author
    "#{label} + #{co_author.first_name} #{co_author.last_name}"
  end

  def single_author_label(row, author, cols)
    return "#{author.first_name} #{author.last_name}" if author
    name = person_display(row, cols)
    name.present? ? "#{name} (unmatched → comment)" : "none (assumed AWBW)"
  end

  # Post-save side effects for a persisted story (skipped on a dry run).
  def finalize_story(row, story, idea, author, co_author, organization, tags)
    return if @dry_run

    comment_authors(row, story, idea, author, co_author)
    comment_wp_id(row, story, idea)
    comment_missing_tags(story, tags)
    apply_grants(row, story, author)
    apply_professional_licenses(row, story, author)
    create_facilitator_affiliation(author, organization)
    create_facilitator_affiliation(co_author, organization)
  end

  def build_story(row, idea:, title:, organization:, windows_type:, author:, co_author:, content:, workshop:, external_title:, credit:, co_credit:)
    featured = featured?(row)
    published = published?(row)
    story = Story.new(
      story_idea: idea,
      title: title,
      rhino_body: content,
      organization: organization,
      windows_type: windows_type,
      author: author&.persisted? ? author : nil,
      co_author: co_author&.persisted? ? co_author : nil,
      workshop: workshop,
      external_workshop_title: external_title,
      story_workshops_attributes: workshop_link_attrs(workshop, external_title),
      youtube_url: youtube_url(row),
      author_credit_preference: credit,
      co_author_credit_preference: co_credit,
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

  def build_idea(row, title:, organization:, windows_type:, author:, co_author:, content:, workshop:, external_title:, credit:, co_credit:)
    idea = StoryIdea.new(
      title: title,
      rhino_body: content,
      organization: organization,
      windows_type: windows_type,
      author: author&.persisted? ? author : nil,
      co_author: co_author&.persisted? ? co_author : nil,
      workshop: workshop,
      external_workshop_title: external_title,
      story_idea_workshops_attributes: workshop_link_attrs(workshop, external_title),
      youtube_url: youtube_url(row),
      author_credit_preference: credit,
      co_author_credit_preference: co_credit,
      permission_given: true,
      created_by: @import_user,
      updated_by: @import_user
    )
    idea.created_at = original_created_at(row) || idea.created_at
    idea
  end

  # A workshop link on the join (story_workshops / story_idea_workshops): the
  # matched Workshop, else the free-text external title. Empty when neither.
  def workshop_link_attrs(workshop, external_title)
    return [ { workshop_id: workshop.id } ] if workshop
    return [ { external_workshop_title: external_title } ] if external_title.present?
    []
  end

  # A story's credit preference is left NULL (it follows the author's live profile)
  # unless the same person has stories with conflicting credits in this import —
  # then the per-story answer is captured so the divergence from the profile is
  # visible. Works for either author via its column set.
  def story_credit(row, cols)
    return unless conflicting_author?(author_key(row, cols))
    credit_for(row, cols)
  end

  # On create the model snapshots the author's profile preference onto a blank
  # credit; undo that so a non-conflicting story persists NULL (follow the profile)
  # rather than a frozen snapshot. A NULL credit is never flagged as diverged.
  def nullify_blank_credit(record, column, credit)
    return if @dry_run || credit.present? || record[column].blank?
    record.update_columns(column => nil)
  end

  # Grants connect to a story only through the author's Scholarship. Without a
  # resolvable author (or a matching Grant), the intended grant is preserved as a
  # Comment on the story instead.
  def apply_grants(row, story, author)
    grant_names_for(row).each do |name|
      grant = Grant.where("LOWER(name) = ?", name.downcase).first
      next comment(story, "Imported grant not in portal: #{name}") unless grant

      if author&.persisted?
        Scholarship.find_or_create_by!(recipient: author, grant: grant)
      else
        comment(story, "Imported grant (no author to link a scholarship): #{grant.name}")
      end
    end
  end

  def grant_names_for(row)
    clean(row["grants"]).split("|").map(&:strip).reject(&:blank?)
  end

  # Professional licenses belong to the author Person. The comma-separated column
  # lists license kinds (credentials); each is found or created for the author.
  # Without an author to attach them to, the kinds are kept as a comment instead.
  def apply_professional_licenses(row, story, author)
    kinds = license_kinds(row)
    return if kinds.empty?

    unless author&.persisted?
      comment(story, "Imported professional license(s) (no author to attach): #{kinds.join(', ')}")
      return
    end

    kinds.each do |kind|
      ProfessionalLicense.find_or_create_by!(person: author, kind: kind, number: nil) do |license|
        license.created_by = @import_user
        license.updated_by = @import_user
      end
    end
  end

  def license_kinds(row)
    clean(row["professional_licenses"]).split(",").map(&:strip).reject(&:blank?)
  end

  # Find or build the story's author Person from the facilitator name. For "AWBW"
  # rows the real facilitator is mis-filed in the last-name column, so the name is
  # split out of it and the story is credited anonymously (see author_credit). A
  # Person requires both names, so a single-name facilitator (e.g. "Teena") or a
  # nameless AWBW row (blank last name) resolves to no author. On a dry run an
  # unseen author is returned unsaved so the preview reflects the new Person.
  def resolve_person(row, cols)
    first = clean(row[cols[:name]])
    last = clean(row[cols[:last]])
    first, last = split_name(last) if awbw?(first)
    return if first.blank? || last.blank?

    find_or_build_person(first, last, person_email(row, cols))
  end

  # The second author only sticks when there's a first author to sit behind (the
  # model requires one) and the two are different people.
  def resolve_co_author(row, author)
    co_author = resolve_person(row, CO_AUTHOR_COLUMNS)
    return unless co_author && author
    return if author_key(row, AUTHOR_COLUMNS) == author_key(row, CO_AUTHOR_COLUMNS)

    co_author
  end

  def find_or_build_person(first, last, email)
    person = email && Person.where("LOWER(email) = ?", email.downcase).first
    person ||= Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?", first.downcase, last.downcase).first
    return person if person

    attrs = { first_name: first, last_name: last, email: email }
    @dry_run ? Person.new(attrs) : Person.create!(attrs)
  end

  def person_email(row, cols)
    email = clean(row[cols[:email]]).presence
    email unless email&.casecmp?("none")
  end

  def split_name(full)
    first, *rest = full.to_s.split
    [ first.to_s, rest.join(" ") ]
  end

  def from_non_awbw?(author)
    author.present? && !author.user&.super_user?
  end

  # "SKIP" or blank → no organization; otherwise the name as written (found or created).
  def resolve_organization(row)
    raw = clean(row["organization_name"])
    return if raw.blank? || raw.casecmp?("SKIP")
    find_or_create_organization(raw)
  end

  # Exact-title match links the story to an existing Workshop; otherwise the
  # free-text title is kept as external_workshop_title. Returns [ workshop, title ].
  def workshop_for(row)
    title = workshop_title(row)
    return [ nil, nil ] if title.blank?

    workshop = Workshop.where("LOWER(title) = ?", title.downcase).first
    workshop ? [ workshop, nil ] : [ nil, title ]
  end

  # The sheet prefixes the workshop with how it resolved ("External title: …" /
  # "Matched workshop: …"); the title itself is what follows.
  def workshop_title(row)
    clean(row["workshop"]).sub(/\A(External title|Matched workshop):\s*/i, "")
  end

  def original_created_at(row)
    date = clean(row["published_date"])
    return if date.blank?
    Time.zone.parse(date)
  rescue ArgumentError
    nil
  end

  # Preserve a facilitator name that couldn't become a credited author (single
  # name, AWBW, or a second author with no first) as a Comment on the story (and
  # its idea) so it isn't lost.
  def comment_authors(row, story, idea, author, co_author)
    comment_unresolved_author(row, story, idea, AUTHOR_COLUMNS) unless author
    comment_unresolved_author(row, story, idea, CO_AUTHOR_COLUMNS) if co_author.nil? && person_named?(row, CO_AUTHOR_COLUMNS)
  end

  def comment_unresolved_author(row, story, idea, cols)
    name = person_display(row, cols)
    return if name.blank?

    [ story, idea ].compact.each { |record| comment(record, "Imported facilitator: #{name}") }
  end

  def person_named?(row, cols)
    clean(row[cols[:name]]).present? || clean(row[cols[:last]]).present?
  end

  # Stories carry no WordPress id column, so the source id is kept as a Comment.
  def comment_wp_id(row, story, idea)
    wp = wp_id(row)
    return if wp == "?"

    [ story, idea ].compact.each { |record| comment(record, "WordPress ID: #{wp}") }
  end

  # Taxonomy the sheet named but the portal doesn't have is recorded on the story
  # so the intended tagging isn't silently dropped.
  def comment_missing_tags(story, tags)
    tags.missing_sectors.each { |name| comment(story, "Imported sector not in portal: #{name}") }
    tags.missing_categories.each do |type, name|
      comment(story, "Imported category not in portal: #{type.present? ? "#{type}: #{name}" : name}")
    end
  end

  def comment(record, body)
    Comment.create!(commentable: record, body: body, created_by: @import_user)
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
  def sync_author_profile(author, row, cols)
    return unless author&.persisted?

    credit = credit_for(row, cols)
    if credit == "anonymous"
      author.update!(anonymous_contributions: true) unless author.anonymous_contributions?
      return
    end

    pref = DISPLAY_PREF_BY_CREDIT[credit]
    return if pref.nil? || (author.display_name_preference.present? && author.display_name_preference != "full_name")

    author.update!(display_name_preference: pref)
  end

  def person_display(row, cols)
    [ clean(row[cols[:name]]), clean(row[cols[:last]]) ].compact_blank.join(" ")
  end

  # Look up the row's resolved Sectors and Categories by name, keeping the names
  # that matched nothing so they can be preserved as comments on the story.
  def resolve_tags(row)
    sectors = []
    missing_sectors = []
    sector_names(row).each do |name|
      sector = Sector.where("LOWER(name) = ?", name.downcase).first
      sector ? sectors << sector : missing_sectors << name
    end

    categories = []
    missing_categories = []
    category_specs(row).each do |type, name|
      category = category_named(name, type)
      category ? categories << category : missing_categories << [ type, name ]
    end

    RowTags.new(
      sectors: sectors.uniq, categories: categories.uniq,
      missing_sectors: missing_sectors.uniq, missing_categories: missing_categories.uniq
    )
  end

  def sector_names(row)
    clean(row["sectors"]).split("|").map(&:strip).reject(&:blank?)
  end

  # Categories are written as "Type: Name" (e.g. "AgeRange: Children").
  def category_specs(row)
    clean(row["categories"]).split("|").map(&:strip).reject(&:blank?).map do |token|
      type, name = token.split(":", 2).map(&:strip)
      name ? [ type, name ] : [ nil, type ]
    end
  end

  def category_named(name, type)
    scope = Category.where("LOWER(categories.name) = ?", name.downcase)
    scope = scope.joins(:category_type).where(category_types: { name: type }) if type.present?
    scope.first
  end

  # Persist tags only for a saved record on a real run; a dry run resolves above
  # but writes nothing.
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

  # Window type must match a WindowsType short_name exactly; a blank or unknown
  # value returns nil so the row is skipped (windows_type is mandatory).
  def windows_type_for(row)
    name = clean(row["window_type"])
    return if name.blank?
    @windows_type_cache.fetch(name) { @windows_type_cache[name] = WindowsType.find_by(short_name: name) }
  end

  def body_html(row, title)
    wpautop(clean_html(row["content"])).presence ||
      "<p>#{ERB::Util.html_escape(title)}</p>"
  end

  # The sheet's editor content uses raw newlines (\r\n) for paragraph breaks
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
    clean(row["youtube_url"]).presence
  end

  def credit_for(row, cols)
    return "anonymous" if awbw?(clean(row[cols[:name]]))
    return "anonymous" if clean(row[cols[:anonymous]]).casecmp?("anonymous")
    AUTHOR_CREDIT_BY_DISPLAY[clean(row[cols[:display]]).downcase] || DEFAULT_AUTHOR_CREDIT
  end

  # The "status" column round-trips this importer's own preview label
  # ("Published story" / "Draft story", each optionally "+ story idea"). On
  # re-upload it is authoritative: "Published"/"Draft" sets the publish state and
  # "story idea" decides whether a StoryIdea is promoted into the story. It falls
  # back to the "published" column / org-presence only when status is blank.
  def status_text(row)
    clean(row["status"]).downcase
  end

  def published?(row)
    status = status_text(row)
    return status.start_with?("published") if status.present?
    clean(row["published"]).casecmp?("yes")
  end

  # The status column decides whether a StoryIdea is wanted ("… + story idea").
  # A blank status falls back to the legacy rule (an idea whenever an org exists).
  def story_idea_requested?(row)
    status = status_text(row)
    return status.include?("story idea") if status.present?
    true
  end

  # A StoryIdea additionally requires an organization (model-level), so a
  # requested idea is still Story-only without one (a warning is recorded).
  def creates_story_idea?(row, organization)
    organization.present? && story_idea_requested?(row)
  end

  def featured?(row)
    truthy?(row["featured"])
  end

  def skipped_action?(row)
    skip_flag(row).present?
  end

  def skip_reason(row)
    skip_flag(row).sub(/\ASkipped\s*[—–-]\s*/, "").presence || "flagged skipped"
  end

  # The skip flag can live in import_action or in the status column ("Skipped —
  # reason"); import_action wins when both carry one.
  def skip_flag(row)
    [ clean(row["import_action"]), clean(row["status"]) ].find { |value| value.start_with?(SKIP_ACTION) }.to_s
  end

  # A re-uploaded sheet can keep a second header row (the human column labels)
  # beneath the snake_case headers; skip it so it never becomes a story. It's
  # recognized when several cells restate their own column's label.
  def header_echo?(row)
    matches = COLUMN_ALIASES.count do |label, key|
      value = row[key]
      value.present? && value.to_s.strip.downcase.gsub(/\s+/, " ") == label
    end
    matches >= 3
  end

  def awbw?(first_name)
    first_name.to_s.strip.casecmp?(AWBW_NAME)
  end

  # Title stripped of any HTML so a story isn't titled with markup.
  def title_text(row)
    clean(strip_html(row["title"]))
  end

  def strip_html(value)
    ActionController::Base.helpers.strip_tags(value.to_s)
  end

  def unique_title(base)
    return base unless title_taken?(base)

    (1..).each do |n|
      candidate = "[COPY #{n}] #{base}"
      return candidate unless title_taken?(candidate)
    end
  end

  def title_taken?(title)
    Story.where("LOWER(title) = ?", title.downcase).exists?
  end

  # Pre-pass: group importable rows by credited person (across both author roles)
  # and collect each person's distinct credit answers, so story_credit knows who
  # disagrees across stories.
  def scan_conflicting_authors
    values = Hash.new { |hash, key| hash[key] = Set.new }
    CSV.foreach(@csv_path, headers: true, header_converters: HEADER_CONVERTER, encoding: "bom|utf-8") do |row|
      next if header_echo?(row) || title_text(row).blank? || skipped_action?(row)
      [ AUTHOR_COLUMNS, CO_AUTHOR_COLUMNS ].each do |cols|
        key = author_key(row, cols)
        values[key] << credit_for(row, cols) if key
      end
    end
    values.select { |_, answers| answers.size > 1 }.keys.to_set
  end

  def author_key(row, cols)
    first = clean(row[cols[:name]])
    last = clean(row[cols[:last]])
    first, last = split_name(last) if awbw?(first)
    return if first.blank? || last.blank?

    person_email(row, cols)&.downcase || "#{first.downcase}|#{last.downcase}"
  end

  def conflicting_author?(key)
    key.present? && @conflicting_authors.include?(key)
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
    clean(row["wp_id"]).presence || "?"
  end

  def truthy?(value)
    %w[1 true yes].include?(clean(value).to_s.downcase)
  end

  # Values may carry HTML entities (e.g. &amp;) even in plain-text columns.
  def clean(value)
    CGI.unescapeHTML(value.to_s).strip
  end

  # Content columns are already HTML; only decode double-encoded entities.
  def clean_html(value)
    value.to_s.strip
  end

  def record_skip(row, reason)
    @result.skipped << "row #{wp_id(row)} (#{title_text(row)}): #{reason}"
    nil
  end

  def record_warning(row, reason)
    @result.warnings << "row #{wp_id(row)} (#{title_text(row)}): #{reason}"
    nil
  end
end
