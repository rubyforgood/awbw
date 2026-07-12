module ApplicationHelper
  # Byline for an AuthorCreditable record. Links to the credited author's person
  # profile when the credit resolves to a searchable person; otherwise renders
  # plain text. The text always honors the credit preference (author_credit), so
  # anonymous and legacy free-text credits never link to a profile.
  def credited_author_link(record, **link_options)
    person = record.author_credit_person
    if person&.profile_is_searchable
      link_to record.author_credit, person_path(person), **link_options
    else
      record.author_credit
    end
  end

  # Tags an admin may use in a form field name / group header that should
  # render (rather than escape) on the public form. Block + inline formatting,
  # links, line breaks, and font sizing/coloring (via <font> or inline style).
  # Anything outside this allowlist is stripped by `sanitize`.
  FORM_LABEL_TAGS = %w[br a p span strong b em i u h1 h2 h3 h4 h5 h6 ul ol li font].freeze
  FORM_LABEL_ATTRIBUTES = %w[href target rel style size color face].freeze

  # Render a form field name / header with a safe subset of HTML allowed.
  # Uses Rails' SafeListSanitizer, which strips dangerous URL schemes
  # (e.g. javascript:) from href and CSS-scrubs the style attribute (dropping
  # unsafe properties/values), so admin-authored markup can't inject XSS.
  def form_label_html(text)
    sanitize(text.to_s, tags: FORM_LABEL_TAGS, attributes: FORM_LABEL_ATTRIBUTES)
  end

  # Render an admin-authored custom message included in a reminder email with the
  # same safe subset of HTML as form labels (bold, italics, links, lists, line
  # breaks). Reuses form_label_html so the allowlist — and its XSS scrubbing —
  # stays in one place. Available to mailer views via `helper ApplicationHelper`.
  def reminder_message_html(text)
    form_label_html(text)
  end

  # The day-relative phrase appended to the default reminder message: " today",
  # " tomorrow", " in N days", or "" when the day count isn't known. Leads with a
  # space so it can be concatenated directly after "...event". The day count is
  # wrapped in <strong> (the message field renders sanitized HTML), so it lands
  # bold in the email.
  def reminder_days_phrase(days_until_event)
    return "" unless days_until_event.is_a?(Integer)
    case days_until_event
    when 0 then " <strong>today</strong>"
    when 1 then " <strong>tomorrow</strong>"
    else " in <strong>#{days_until_event} days</strong>"
    end
  end

  # Default text pre-filled into the editable reminder message on the bulk
  # reminder page (admins can edit or clear it). The day count is resolved when
  # the page renders — it's event-level, so the same for every recipient.
  def default_reminder_message(days_until_event)
    organization = ENV.fetch("ORGANIZATION_NAME", "AWBW")
    "This is a reminder that you're registered for the following #{organization} event#{reminder_days_phrase(days_until_event)}."
  end

  # Default subject line pre-filled into the editable subject field on the bulk
  # reminder page (admins can edit it). Mirrors the mailer's fallback subject; the
  # event date is event-level, resolved here in the app default time zone.
  def default_reminder_subject(event)
    date_suffix = event.start_date.present? ? " – #{event.start_date.in_time_zone.strftime('%B %-d, %Y')}" : ""
    "AWBW Portal: Reminder: #{event.title}#{date_suffix}"
  end

  # Tokens an admin can drop into a form header; each is filled from the event the
  # form is rendered for (see form_header_html). A standalone registration form is
  # shared across events, so the header can't hard-code event specifics. Each entry:
  # [label, example] — surfaced as a reference on the form editor. Keep the keys in
  # sync with the substitutions in form_header_html.
  FORM_HEADER_TOKENS = {
    "{{event_title}}" => [ "Event title", "AWBW Facilitator Training" ],
    "{{event_dates}}" => [ "Event date(s)", "July 23-24, 2026" ],
    "{{event_times}}" => [ "Event start-end time", "9 am - 4:30 pm PST" ],
    "{{event_fee}}" => [ "Registration fee", "$1,500" ],
    "{{event_platform}}" => [ "Virtual platform", "Zoom" ],
    "{{event_location}}" => [ "In-person location", "Los Angeles, CA" ],
    "{{event_month_year}}" => [ "Event month and year", "July 2026" ],
    "{{registration_close}}" => [ "Registration close date", "July 20 at 9am PST" ]
  }.freeze

  # Render a form header, filling event-driven tokens (see FORM_HEADER_TOKENS) from
  # the event the form is being shown for. The public registration pages pass
  # `event:`; the standalone form preview has none, so tokens fall back to a neutral
  # phrase. HTML is sanitized via form_label_html.
  def form_header_html(form, event: nil)
    text = form.header.to_s
      .gsub("{{event_title}}", event&.title.presence || "this event")
      .gsub("{{event_dates}}", event_dates_label(event) || "the event dates")
      .gsub("{{event_times}}", event_times_label(event) || "the scheduled time")
      .gsub("{{event_fee}}", event_fee_label(event) || "the registration fee")
      .gsub("{{event_platform}}", event_platform_label(event) || "online")
      .gsub("{{event_location}}", event_location_label(event) || "the event location")
      .gsub("{{event_month_year}}", event&.start_date&.strftime("%B %Y") || "upcoming")
      .gsub("{{registration_close}}", event_registration_close_label(event) || "soon")
    form_label_html(text)
  end

  # True when the header contains any {{token}} placeholder, so previews (which
  # have no event in scope) can flag that the live values come from the event.
  def form_header_uses_tokens?(form)
    header = form&.header.to_s
    FORM_HEADER_TOKENS.keys.any? { |token| header.include?(token) }
  end

  # Weekday-prefixed date for the registration details panel, without the year
  # (the year lives in the page hero) — e.g. "Wednesday, August 12" or
  # "Thursday-Friday, July 23-24". Nil when the event has no start date.
  def event_dates_detail_label(event)
    return unless event&.start_date
    s = event.start_date.in_time_zone(Time.zone)
    e = (event.end_date || event.start_date).in_time_zone(Time.zone)
    return s.strftime("%A, %B %-d") if s.to_date == e.to_date
    if s.year == e.year && s.month == e.month
      "#{s.strftime("%A")}-#{e.strftime("%A")}, #{s.strftime("%B %-d")}-#{e.strftime("%-d")}"
    else
      "#{s.strftime("%A, %B %-d")} - #{e.strftime("%A, %B %-d")}"
    end
  end

  # Event date or date range as plain text (e.g. "July 23-24, 2026"), mirroring the
  # event show page's date line, or nil when the event has no start date.
  def event_dates_label(event)
    return unless event&.start_date
    s = event.start_date.in_time_zone(Time.zone)
    e = (event.end_date || event.start_date).in_time_zone(Time.zone)
    return s.strftime("%B %-d, %Y") if s.to_date == e.to_date
    if s.year == e.year && s.month == e.month
      "#{s.strftime("%B %-d")}-#{e.strftime("%-d")}, #{s.year}"
    elsif s.year == e.year
      "#{s.strftime("%B %-d")} - #{e.strftime("%B %-d")}, #{s.year}"
    else
      "#{s.strftime("%B %-d, %Y")} - #{e.strftime("%B %-d, %Y")}"
    end
  end

  # Event start-end time as plain text (e.g. "9 am - 4:30 pm PST"), mirroring the
  # event show page's time formatting (minutes hidden when :00), or nil with no start.
  def event_times_label(event)
    return unless event&.start_date
    s = event.start_date.in_time_zone(Time.zone)
    e = (event.end_date || event.start_date).in_time_zone(Time.zone)
    format = ->(d) do
      t = d.strftime("%-l")
      t += ":#{d.strftime("%M")}" unless d.strftime("%M") == "00"
      "#{t} #{d.strftime("%P")}"
    end
    zone = s.strftime("%Z")
    return "#{format.call(s)} #{zone}" if s.hour == e.hour && s.min == e.min
    "#{format.call(s)} - #{format.call(e)} #{zone}"
  end

  # Registration fee as plain text ("$1,500" or "Free"), or nil when no cost is set.
  def event_fee_label(event)
    return unless event && event.cost_cents.present?
    event.cost_cents.zero? ? "Free" : dollars_from_cents(event.cost_cents)
  end

  # Virtual platform label (e.g. "Zoom"), only for events with a videoconference
  # link configured; nil otherwise (in-person or unset). Uses the event's own
  # label, falling back to the platform name derived from the link's host when
  # the label is blank.
  def event_platform_label(event)
    return unless event&.videoconference_url.present?
    event.videoconference_label.presence || event.decorate.videoconference_domain
  end

  # In-person location name (e.g. "Los Angeles, CA"), or nil when the event has no
  # physical location set.
  def event_location_label(event)
    event&.location&.name.presence
  end

  # Registration close date for form-header interpolation and the details panel,
  # e.g. "July 20 at 9am PST": plain day (no ordinal), no year, compact time
  # (minutes only when not on the hour). Nil when there's no close date. The
  # date and time parts are split out so the details panel can grey out the time.
  def event_registration_close_label(event)
    return unless event&.registration_close_date
    "#{event_registration_close_date_label(event)} #{event_registration_close_time_label(event)}"
  end

  # Just the day portion of the registration close (e.g. "July 20"), or nil.
  def event_registration_close_date_label(event)
    close = event&.registration_close_date
    return unless close
    close.in_time_zone(Time.zone).strftime("%B %-d")
  end

  # Just the time portion of the registration close, prefixed with "at" and
  # carrying the zone (e.g. "at 9am PST"); minutes hidden on the hour. Nil when
  # there's no close date.
  def event_registration_close_time_label(event)
    close = event&.registration_close_date
    return unless close
    local = close.in_time_zone(Time.zone)
    time = local.strftime("%-l")
    time += ":#{local.strftime("%M")}" unless local.strftime("%M") == "00"
    time += local.strftime("%P")
    "at #{time} #{local.strftime("%Z")}"
  end

  # Default registration close datetime suggested on the event form: 9am on the
  # Monday before the event's start date. New events without a start date yet
  # fall back to two days out at 9am.
  def event_registration_close_default(event)
    start = event&.start_date
    base = start ? (start.in_time_zone(Time.zone) - 1.day).beginning_of_week(:monday) : 2.days.from_now
    base.change(hour: 9, min: 0)
  end

  # Rainbow gradient accent bar shown beside form section headers.
  def form_section_bar_class
    "h-5 w-1 rounded-full bg-[linear-gradient(to_bottom,#ec4899,#f97316,#22c55e,#3b82f6,#8b5cf6)]"
  end

  # Returns the selectable options for a form field as [ label, value, description ]
  # tuples (description is nil for sectors and present only for categories that have
  # one), or nil when the field has no dynamic source (callers fall back to the
  # field's own stored answer options). Shared by the public form's radio and
  # checkbox rendering so a dynamic field renders the same options regardless
  # of which single/multiple choice type it was set to. The set of valid submission
  # values for these is mirrored by FormField#allowed_answer_values.
  def dynamic_form_field_options(field)
    case field.field_identifier
    when *FormField::SECTOR_FIELD_IDENTIFIERS
      field.sector_options.map { |sector| [ sector.name, sector.id.to_s, sector.description ] }
    when *FormField::DYNAMIC_FIELD_CATEGORY_TYPES.keys
      field.dynamic_categories.map { |category| [ category.name, category.id.to_s, category.description ] }
    end
  end

  # True when a dropdown field carries an "Other" option that the public form
  # strips (dropdowns have no free-text input). Checks the field's effective
  # options — dynamic sources (sectors/categories) as well as author-managed
  # stored options — so the editor and preview warn wherever "Other" would
  # silently disappear.
  def dropdown_hides_other?(field)
    return false unless field.answer_type == "single_select_dropdown"

    options = dynamic_form_field_options(field) ||
      field.form_field_answer_options.includes(:answer_option).map { |ffao| [ ffao.answer_option.name ] }
    options.any? { |label, _| FormField.other_option?(label) }
  end

  # Describes where a dynamic-option field's choices come from, for the form
  # editor badge: a sentence-case label and a link to the filtered admin list
  # that manages those options. Returns nil for fields with stored options.
  def form_field_option_source(field)
    if field.field_identifier.in?(FormField::SECTOR_FIELD_IDENTIFIERS)
      { label: "Sectors", path: sectors_path }
    elsif (type_name = FormField::DYNAMIC_FIELD_CATEGORY_TYPES[field.field_identifier])
      type = CategoryType.find_by(name: type_name)
      return unless type
      { label: "#{type.name.underscore.humanize} categories", path: categories_path(category_type_id: type.id) }
    end
  end

  INDEX_BUTTON_ICONS = {
    community_news:      "fa-newspaper",
    stories:             "fa-book-open",
    story_ideas:         "fa-lightbulb",
    workshop_logs:       "fa-clipboard-list",
    event_registrations: "fa-ticket",
    monthly_reports:     "fa-file-lines",
    events:              "fa-calendar-days",
    people:              "fa-user",
    organizations:       "fa-building",
    workshops:           "fa-chalkboard-user",
    workshop_variations: "fa-shapes",
    resources:           "fa-book",
    scholarships:        "fa-graduation-cap",
    notifications:       "fa-bell",
    grants:              "fa-hand-holding-dollar",
    form_submissions:    "fa-file-signature",
    payments:            "fa-money-check-dollar"
  }.freeze

  # Themed card-style link to a filtered index. The collection drives the
  # model identity (DomainTheme color + default label + default icon + count
  # + default index path). Pass `params:` for filter params, or `path:` to
  # override entirely (e.g. nested routes).
  def index_button(collection, params: {}, path: nil, label: nil, icon: nil, hide_count: false, hide_icon: false, data: {})
    klass = collection.klass
    key = klass.name.underscore.pluralize.to_sym
    label ||= key.to_s.humanize
    icon  ||= INDEX_BUTTON_ICONS[key] || "fa-folder"
    path  ||= send("#{klass.model_name.route_key}_path", params)

    bg       = DomainTheme.bg_class_for(key, intensity: 50)
    hover_bg = DomainTheme.bg_class_for(key, intensity: 50, hover: true)
    text     = DomainTheme.text_class_for(key)
    border   = DomainTheme.border_class_for(key)

    link_to path,
            data: { turbo_prefetch: false }.merge(data),
            class: "group flex items-center gap-3 w-full px-3 py-2 rounded-lg
                    border #{border} #{bg} #{hover_bg}
                    transition-colors duration-200 shadow-sm" do
      icon_tag = if hide_icon
        "".html_safe
      else
        content_tag(:span, class: "#{text} w-5 text-center") do
          content_tag(:i, "", class: "fa-solid #{icon}")
        end
      end

      label_tag = content_tag(:span, label, class: "font-medium #{text} truncate")

      count_tag = if hide_count
        "".html_safe
      else
        content_tag(:span,
                    number_with_delimiter(collection.count),
                    class: "ml-auto inline-flex items-center justify-center min-w-[2.25rem] px-2 py-0.5 text-sm font-semibold rounded-full bg-white #{text} border #{border}")
      end

      icon_tag + label_tag + count_tag
    end
  end

  # Best viewable path for a record (e.g. a notification's noticeable), or nil
  # when its model has no route. FormSubmissions have no polymorphic route, so
  # they get a tailored destination via form_submission_link_path.
  def routable_path(record)
    return form_submission_link_path(record) if record.is_a?(FormSubmission)
    polymorphic_path(record)
  rescue NoMethodError
    nil
  end

  # Where to view a form submission. When the submitter has a public event
  # registration, send the viewer to their registration details page (the public
  # "ticket"/details view, keyed by the registration slug). The event is resolved
  # directly, or indirectly through the form's matching join role for older
  # submissions without a stored event. Otherwise — bulk payments and event-less
  # submissions, which have no registration — fall back to the form submission
  # show page.
  def form_submission_link_path(submission)
    event = submission.resolved_event
    registration = event && submission.person.event_registrations.find_by(event: event)
    return event_public_registration_path(event, reg: registration.slug) if registration&.slug.present?
    form_submission_path(submission)
  end

  # A friendly type name for a noticeable record, e.g. "Registration" or "Bulk
  # payment" rather than the raw model name ("EventRegistration").
  def noticeable_type_label(record)
    return "Registration" if record.is_a?(EventRegistration)

    if record.is_a?(FormSubmission)
      return record.role == "bulk_payment" ? "Bulk payment" : "Form submission"
    end

    record.class.name.underscore.humanize
  end

  # A human-friendly name for a noticeable record (the registrant and event for a
  # registration, the submitter and form for a submission, otherwise the record's
  # own title/name), so links read as the thing rather than its model class.
  def noticeable_label(record)
    label = case record
    when EventRegistration
      [ record.registrant&.name, record.event&.title ].compact_blank.join(" · ")
    when FormSubmission
      [ record.person&.name, record.form&.name ].compact_blank.join(" · ")
    else
      record.try(:title) || record.try(:name) || record.try(:full_name)
    end

    label.presence || "##{record.id}"
  end

  def search_page(params)
    params[:search] ? params[:search][:page] : 1
  end

  def checked?(param = false)
    param == "1"
  end

  def months_with_year
    (1..12).collect { |m| "#{m}/#{today.year}" }
  end

  def current_month_with_year
    today.strftime("%_m/%Y")
  end

  def current_year
    today.year
  end

  def today
    Date.today
  end

  def display_banner
    # Cache banners to avoid repeated queries during page render
    @banners ||= Banner.published.select("id, content").to_a
    return if @banners.empty?

    safe_content_array = @banners.map { |banner|
      sanitize(
        banner.content,
        tags: %w[a],
        attributes: %w[href]
      )
    }

    safe_content = safe_content_array.join("<br>")

    content_tag(:div, id: "banner-news", class: "bg-yellow-200 text-black text-center px-4 py-2") do
      content_tag(:div, safe_content.html_safe, class: "font-medium")
    end
  end

  def sortable_field_display_name(name)
    case name
    when :adult
      "Adult Windows"
    when :children
      "Children's Windows"
    else
      name.to_s.titleize
    end
  end

  def icon_for_mimetype(mime)
    mimes = {
        "image" => "fa-file-image",
        "audio" => "fa-file-audio",
        "video" => "fa-file-video",
        # Documents
        "application/pdf" => "fa-file-pdf",
        "application/msword" => "fa-file-word",
        "application/vnd.ms-word" => "fa-file-word",
        "application/vnd.oasis.opendocument.text" => "fa-file-word",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "fa-file-word",
        'application/vnd.ms-excel': "fa-file-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "fa-file-excel",
        "application/vnd.oasis.opendocument.spreadsheet" => "fa-file-excel",
        "application/vnd.ms-powerpoint" => "fa-file-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml" => "fa-file-powerpoint",
        "application/vnd.oasis.opendocument.presentation" => "fa-file-powerpoint",

        # Archives
        "application/gzip" => "fa-file-archive"
    }

    if mime
      m = mimes[mime.split("/").first]
      m ||= mimes[mime]
    end

    m ||= "fa-file"

    "fas #{m}"
  end

  def display_count(value)
    value.to_i.zero? ? "--" : number_with_delimiter(value)
  end

  # Currency for an amount given in cents, dropping the cents when the amount is
  # a whole number of dollars: 150000 → "$1,500", 75050 → "$750.50".
  def dollars_from_cents(cents)
    MoneyFormatter.dollars_from_cents(cents)
  end

  # Like dollars_from_cents but preserves a leading minus for negative amounts.
  def signed_dollars_from_cents(cents)
    MoneyFormatter.signed_dollars_from_cents(cents)
  end

  def navbar_bg_class
    if staging_environment? && !params[:nav_bg_primary].present?
      "bg-red-600"
    else
      "bg-primary"
    end
  end

  def staging_environment?
    ENV["RAILS_ENV"] == "staging" || Rails.env == "staging"
  end

  def favicon_file
    case Rails.env.to_s
    when "production"
      "logo-circle.png"
    when "staging"
      "favicon.png"
    else
      "theme_default.png"
    end
  end

  def email_confirmation_icon(user)
    if user.unconfirmed_email.present?
      content_tag(:span, "pending confirmation", class: "text-yellow-600 font-medium", title: "Email change pending confirmation")
    elsif user.confirmed_at.present?
      content_tag(:span, "confirmed", class: "text-green-600 font-medium", title: "Email confirmed")
    else
      content_tag(:span, "unconfirmed", class: "text-red-600 font-medium", title: "Email not confirmed")
    end
  end

  def email_label_with_confirmation_icon(user)
    "Email #{email_confirmation_icon(user)}".html_safe
  end

  # Returns checkbox options for the visibility filter dropdown.
  # Each entry is [label, param_name, admin_only].
  # Options adapt to the model's columns and the user's role.
  def visibility_filter_options(model_class, admin:, authenticated:)
    cols = model_class.column_names
    options = []

    if admin
      options << [ "Published", :published, true ]
      options << [ "Unpublished", :unpublished, true ]
      options << [ "Featured", :featured, false ]             if cols.include?("featured")
      options << [ "Publicly Visible", :publicly_visible, false ] if cols.include?("publicly_visible")
      options << [ "Publicly Featured", :publicly_featured, false ] if cols.include?("publicly_featured")
    elsif authenticated
      options << [ "Not Featured", :not_featured, false ]     if cols.include?("featured")
      options << [ "Featured", :featured, false ]             if cols.include?("featured")
      options << [ "Publicly Visible", :publicly_visible, false ] if cols.include?("publicly_visible")
      options << [ "Publicly Featured", :publicly_featured, false ] if cols.include?("publicly_featured")
    else
      options << [ "Not Publicly Featured", :not_publicly_featured, false ] if cols.include?("publicly_featured")
      options << [ "Publicly Featured", :publicly_featured, false ]         if cols.include?("publicly_featured")
    end

    options
  end

  # Fundamental US time zones only (for user preference dropdown).
  # Order: Eastern → Pacific, then Alaska, Hawaii, Arizona.
  def default_organization_for_form(object)
    return object.organization if object.organization.present?

    if current_user.super_user?
      Organization.find_by(name: ENV["ORGANIZATION_NAME"])
    elsif current_user.person&.affiliations&.count == 1
      current_user.person.primary_organization
    end
  end

  def custom_caret_style
    "background-image:url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%236b7280' d='M2 4l4 4 4-4'/%3E%3C/svg%3E\");background-position:right 0.75rem center;background-size:12px;background-repeat:no-repeat;"
  end

  def select_caret_class(blank:)
    "w-full px-3 py-2 pr-10 border border-gray-300 rounded-lg appearance-none #{"select-placeholder" if blank}"
  end

  def select_caret_onchange
    "if(this.value){this.classList.remove('select-placeholder')}else{this.classList.add('select-placeholder')}"
  end

  def hidden_fields_for_params(hash, prefix = nil)
    return "".html_safe if hash.blank?

    fields = []
    hash.each do |key, value|
      field_name = prefix ? "#{prefix}[#{key}]" : key.to_s
      case value
      when ActionDispatch::Http::UploadedFile
        next
      when Hash
        fields << hidden_fields_for_params(value, field_name)
      when Array
        value.each_with_index do |item, i|
          if item.is_a?(Hash)
            fields << hidden_fields_for_params(item, "#{field_name}[#{i}]")
          else
            fields << tag.input(type: "hidden", name: "#{field_name}[]", value: item)
          end
        end
      else
        next if key.to_s == "id" && value.blank?
        fields << tag.input(type: "hidden", name: field_name, value: value)
      end
    end
    safe_join(fields)
  end

  def us_time_zone_fundamentals
    zone_names = [
      "Eastern Time (US & Canada)",
      "Central Time (US & Canada)",
      "Mountain Time (US & Canada)",
      "Pacific Time (US & Canada)",
      "Alaska",
      "Hawaii",
      "Arizona"
    ]
    ActiveSupport::TimeZone.us_zones.select { |z| zone_names.include?(z.name) }.sort_by { |z| zone_names.index(z.name) }.map { |z| [ z.to_s, z.name ] }
  end
end
