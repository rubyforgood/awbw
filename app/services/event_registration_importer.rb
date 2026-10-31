require "csv"
require "bigdecimal"

# Bulk-imports registrants into one existing event from an uploaded CSV — a
# historical backfill of who registered and attended, live or on-demand, training
# or not. Each row simulates the registration a real submission would create, then
# hands off to the same capture and reconciliation services:
#
#   * Person — with an email, matched on the PublicRegistration rule (email + last
#     name, tolerant of a first-name/legal-name swap). Without one, matched by name
#     at the row's organization, else by a name only one person carries
#     (PersonNameMatcher). A miss creates the person, attributed to the importing
#     admin; an email-less one gets the next free N@example.com placeholder.
#   * EventRegistration — found or created, one per registrant per event. Its
#     status comes from the Status column (Attended when blank, or derived from
#     Day N columns when only those are filled), but only where the portal has no
#     deliberate outcome of its own: an attended, cancelled, no-show,
#     transferred-out or incomplete registration keeps what it has, and the row's
#     status is recorded as a comment on it instead. Attended marks every day
#     complete unless Day N columns say otherwise.
#   * FormSubmission (role "registration") — the import's OWN submission, marked
#     `imported_from`, carrying the answers this event's form asks; created
#     alongside (never in place of) a real registrant's submission.
#   * Organization — matched by name, tolerating punctuation and legal suffixes
#     (OrganizationServices::NameMatcher), then filled in through
#     OrganizationServices::CaptureFromSubmission: website, type, work address, and
#     the job (+ facilitator, on a training) affiliations. Unmatched names are left
#     for the link-organization queue, never invented here.
#   * Profile — mailing address, phone, pronouns, sectors and age groups through
#     PersonServices::CaptureFromSubmission. A matched person's (and org's) existing
#     values are kept; the sheet only fills blanks and adds new addresses beside.
#   * CE — enrolled when the row asks for CE and the event offers hours.
#   * Money — a Scholarship first, then the AmountPaid payment (registration, then
#     a CE the row asked for), then a Discount comping whatever a paying row still
#     owes, so it reads Paid. A CE the row doesn't mention is left alone.
#
# No emails are sent and no mailing-list subscription is made. Runs in a
# transaction with a dry_run mode that rolls back for the preview.
class EventRegistrationImporter
  DEFAULT_STATUS = "attended".freeze

  # Statuses the sheet never overwrites: a deliberate in-app outcome outranks a
  # spreadsheet read off whatever the trainer wrote down, so an attended
  # registration is never walked back and a cancelled / no-show / transferred-out /
  # incomplete one is never revived. Only a still-"registered" registration takes
  # the row's status; otherwise the row's status becomes a comment on it.
  PORTAL_WINS_STATUSES = (EventRegistration::INACTIVE_STATUSES + %w[attended incomplete_attendance]).freeze

  # Topic on the comment that records a status the import declined to apply.
  COMMENT_TOPIC = "Spreadsheet import".freeze

  # Stands in for an attendee the sheet counted but didn't name, so the bulk payment
  # card lists a row to link once someone works out who they were.
  UNNAMED_ATTENDEE = { "first_name" => "TBD", "last_name" => "TBD" }.freeze

  # metadata key stamped on the submission the import creates, so we can find our
  # own submission on a re-run (idempotency) without ever matching a real one.
  IMPORT_SOURCE_KEY = "imported_from".freeze

  # metadata key naming the batch a payment covers, so a re-run finds the same one.
  BULK_REF_KEY = "bulk_payment_ref".freeze

  # Name for the bulk payment form the import falls back to creating when the
  # install has none to attach.
  BULK_PAYMENT_FORM_NAME = "Bulk payment".freeze

  # Row field → registration-form field_identifier for the answers that pass through
  # unchanged; sectors, age groups, and the org/contact types are resolved first.
  PLAIN_ANSWERS = {
    first_name: "first_name",
    last_name: "last_name",
    email: "primary_email",
    pronouns: "pronouns",
    secondary_email: "secondary_email",
    organization: "organization_name",
    position: "organization_position",
    organization_website: "organization_website",
    organization_street: "organization_street",
    organization_city: "organization_city",
    organization_state: "organization_state",
    organization_zip: "organization_zip",
    organization_country: "organization_country",
    mailing_street: "mailing_street",
    mailing_city: "mailing_city",
    mailing_state: "mailing_state",
    mailing_zip: "mailing_zip",
    mailing_country: "mailing_country",
    phone: "phone"
  }.freeze

  CONTACT_TYPES = %w[Work Personal].freeze

  # Normalized PaymentType token → the STI Payment subclass to create. A blank
  # type on a row carrying an amount falls back to cash; an unrecognized token
  # records no payment (surfaced in the preview) rather than guessing.
  PAYMENT_TYPES = {
    "cash" => CashPayment,
    "check" => CheckPayment,
    "cheque" => CheckPayment,
    "card" => ExternalProcessorPayment,
    "credit" => ExternalProcessorPayment,
    "creditcard" => ExternalProcessorPayment,
    "debit" => ExternalProcessorPayment,
    "stripe" => ExternalProcessorPayment,
    "online" => ExternalProcessorPayment,
    "external" => ExternalProcessorPayment
  }.freeze
  DEFAULT_PAYMENT_TYPE = CashPayment

  PAYMENT_TYPE_LABELS = {
    "CashPayment" => "Cash",
    "CheckPayment" => "Check",
    "ExternalProcessorPayment" => "Card"
  }.freeze

  SUPPORTED_EXTENSIONS = %w[csv].freeze

  # An event can be imported into only when it has a registration form carrying an
  # organization-name field — without it the typed org has nowhere to live and the
  # reconciliation queue would never see it.
  def self.importable?(event)
    form = event.registration_form
    return false unless form

    form.form_fields.exists?(field_identifier: FormField::ORGANIZATION_NAME_FIELD_IDENTIFIER)
  end

  Result = Struct.new(
    :rows_processed, :people_created, :people_matched, :people_matched_by_name, :placeholder_emails,
    :registrations_created, :registrations_kept, :registrations_updated, :registrations_unchanged,
    :organizations_linked, :organizations_to_reconcile,
    :payments_recorded, :payments_amount_cents,
    :scholarships_recorded, :scholarships_amount_cents,
    :discounts_recorded, :discounts_amount_cents,
    :ce_enrollments, :unrecognized_headers, :untranslated_addresses,
    :skipped, :rows,
    keyword_init: true
  ) do
    def registrations_total
      registrations_created + registrations_kept + registrations_updated + registrations_unchanged
    end

    def summary
      [
        "rows processed: #{rows_processed}",
        "people matched: #{people_matched} (#{people_matched_by_name} by name), created: #{people_created} " \
          "(#{placeholder_emails} with a placeholder email)",
        "registrations created: #{registrations_created}, status updated: #{registrations_updated}, " \
          "portal status kept: #{registrations_kept}, unchanged: #{registrations_unchanged}",
        "organizations linked: #{organizations_linked}, to reconcile: #{organizations_to_reconcile}",
        "scholarships recorded: #{scholarships_recorded} (#{MoneyFormatter.dollars_from_cents(scholarships_amount_cents)})",
        "payments recorded: #{payments_recorded} (#{MoneyFormatter.dollars_from_cents(payments_amount_cents)})",
        "discounts recorded: #{discounts_recorded} (#{MoneyFormatter.dollars_from_cents(discounts_amount_cents)})",
        "CE enrollments: #{ce_enrollments}",
        "skipped: #{skipped.size}"
      ].join("\n")
    end
  end

  # One row's preview outcome; the *_status symbols render as badges in the view.
  RowPreview = Struct.new(
    :number, :first_name, :last_name, :email, :organization_name,
    :person_status, :person_label, :placeholder_email,
    :status, :status_from_sheet, :registration_status, :previous_status,
    :organization_status, :organization_label,
    :payment_status, :payment_label, :payment_amount_cents, :payment_total_cents, :discount_cents,
    :owed_cents, :bulk_ref, :bulk_size,
    :scholarship_cents, :ce_status, :details, :warnings,
    :skipped_reason,
    keyword_init: true
  )

  def self.call(...)
    new(...).call
  end

  def initialize(file_path:, event:, import_user: nil, source: nil, dry_run: false)
    @file_path = file_path
    @event = event
    @registration_form = event.registration_form
    @import_user = import_user
    @source = source.presence || "spreadsheet import"
    @dry_run = dry_run
    @result = Result.new(
      rows_processed: 0, people_created: 0, people_matched: 0, people_matched_by_name: 0, placeholder_emails: 0,
      registrations_created: 0, registrations_kept: 0, registrations_updated: 0, registrations_unchanged: 0,
      organizations_linked: 0, organizations_to_reconcile: 0,
      payments_recorded: 0, payments_amount_cents: 0,
      scholarships_recorded: 0, scholarships_amount_cents: 0,
      discounts_recorded: 0, discounts_amount_cents: 0,
      ce_enrollments: 0, unrecognized_headers: [], untranslated_addresses: {},
      skipped: [], rows: []
    )
    @organization_matcher = OrganizationServices::NameMatcher.new
    @address_translation = AddressTranslation.new
    @organization_cache = {}
    @form_field_cache = {}
    @seen_row_keys = {}
    @payment_batches = {}
    @placeholder_emails_issued = {}
  end

  def call
    ActiveRecord::Base.transaction do
      each_row { |row, number| process_row(row, number) }
      # Money last: rows sharing a BulkPayment reference are one payment, so the
      # split can't be known until every row has been read.
      @payment_batches.each_value { |members| apply_payment_batch(members) }
      raise ActiveRecord::Rollback if @dry_run
    end
    unmatched = @address_translation.unmatched
    @result.untranslated_addresses = %i[country state].select { |field| unmatched[field].any? }.index_with { |field| unmatched[field].to_h }
    @result
  end

  private

  def each_row
    header = nil
    number = 0
    # bom|utf-8 strips the byte-order mark Excel prepends to the first header cell.
    CSV.foreach(@file_path, encoding: "bom|utf-8") do |values|
      if header.nil?
        header = values.map { |label| Columns.field_for(label) }
        @result.unrecognized_headers = values.zip(header).filter_map { |label, field| label.to_s.strip.presence if field.nil? }
        next
      end
      next if values.all?(&:blank?)

      number += 1
      yield header.zip(values).reject { |field, _| field.nil? }.to_h, number
    end
  end

  def process_row(row, number)
    @result.rows_processed += 1
    values = row.transform_values { |value| clean(value) }
    values[:email] = values[:email]&.downcase
    preview = RowPreview.new(
      number: number, first_name: values[:first_name], last_name: values[:last_name],
      email: values[:email], organization_name: values[:organization], details: [], warnings: []
    )

    coded = person_for_filemaker_code(values[:filemaker_code])
    if coded
      preview.first_name ||= coded.first_name
      preview.last_name ||= coded.last_name
      preview.email ||= coded.email
    else
      missing = [ [ "first name", values[:first_name] ], [ "last name", values[:last_name] ] ]
        .select { |_label, value| value.blank? }.map(&:first)
      return skip(preview, "missing #{missing.join(", ")}") if missing.any?
    end

    status = resolve_status(values)
    return skip(preview, "unknown status “#{values[:status]}”") if status == :invalid

    key = row_key(values)
    return skip(preview, "duplicate of row #{@seen_row_keys[key]} in this file") if @seen_row_keys.key?(key)
    @seen_row_keys[key] = number

    preview.status = preview.status_from_sheet = status
    organization = resolve_organization(values[:organization], preview)
    person = resolve_person(values, organization, preview, coded)
    registration = resolve_registration(person, status, preview)
    answers = build_answers(values, preview)
    set_money_preview(values, preview)
    set_detail_preview(values, answers, preview)

    persist_registration(person, registration, values, organization, answers, preview) unless @dry_run
    record_payment_intent(person, registration, values, preview) if preview.payment_status == :will_record

    @result.rows << preview
  end

  def row_key(values)
    return "code #{values[:filemaker_code]}" if values[:filemaker_code]
    return "email #{values[:email]} #{values[:last_name].downcase}" if values[:email]

    "name #{values[:first_name]} #{values[:last_name]} #{values[:organization]}".downcase
  end

  # The row's Status; when blank, the Day N columns decide it if any are filled,
  # else the import's default.
  def resolve_status(values)
    status = Columns.status(values[:status])
    return status if status

    days = day_values(values)
    return DEFAULT_STATUS if days.empty?

    EventRegistration.new(event: @event, **day_attributes(days)).attendance_status_for_days
  end

  def day_values(values)
    Columns::DAY_KEYS.filter_map do |day, key|
      next if day > @event.day_count

      flag = Columns.yes_no(values[key])
      [ day, flag ] unless flag.nil?
    end.to_h
  end

  def day_attributes(days)
    days.to_h { |day, flag| [ :"completed_day_#{day}", flag ] }
  end

  # ── People ──────────────────────────────────────────────────────────────

  def resolve_person(values, organization, preview, coded = nil)
    existing, basis = coded ? [ coded, :filemaker_code ] : find_matching_person(values, organization)
    if existing
      @result.people_matched += 1
      @result.people_matched_by_name += 1 if basis && basis != :filemaker_code
      preview.person_status = basis ? :"matched_by_#{basis}" : :matched
      preview.person_label = existing.full_name
      return existing
    end

    @result.people_created += 1
    preview.person_status = :new
    preview.person_label = "#{values[:first_name]} #{values[:last_name]}"
    person = Person.new(
      first_name: values[:nickname] || values[:first_name], last_name: values[:last_name], email: values[:email],
      created_by: @import_user, updated_by: @import_user
    )
    person.email = placeholder_email(person, preview) if person.email.blank?
    person.save! unless @dry_run
    person
  end

  # A FileMaker code names the person outright: the Rolodex import carries each
  # archive row's id onto the person it became, so a registration row exported
  # beside it needs no name or email to be matched.
  def person_for_filemaker_code(code)
    return if code.blank?

    Person.with_filemaker_code(code).first
  end

  def find_matching_person(values, organization)
    if values[:email]
      person = PersonMatcher.call(email: values[:email], last_name: values[:last_name], first_names: [ values[:first_name], values[:nickname] ])
      return [ person, nil ]
    end

    match = PersonNameMatcher.call(first_name: values[:first_name], last_name: values[:last_name], organization: organization)
    [ match.person, match.basis ]
  end

  # Person's own "no email on file" placeholder, numbered per name so two people
  # sharing one can be told apart. Rows already previewed in this file count as
  # taken, since a dry run saves nobody for the next lookup to find.
  def placeholder_email(person, preview)
    taken = @placeholder_emails_issued[name_key(person)] ||= []
    address = person.next_free_placeholder_email
    address = bump_placeholder(address) while taken.include?(address)
    taken << address
    @result.placeholder_emails += 1
    preview.placeholder_email = address
  end

  def bump_placeholder(address)
    PlaceholderEmail.at(PlaceholderEmail.number_in(address) + 1)
  end

  def name_key(person)
    "#{person.first_name} #{person.last_name}".downcase
  end

  # ── Registrations ───────────────────────────────────────────────────────

  def resolve_registration(person, status, preview)
    existing = @event.event_registrations.find_by(registrant: person) unless person.new_record?

    if existing.nil?
      count_registration(preview, :created)
      return if @dry_run

      build_registration(person, status)
    elsif existing.status == status
      keep_registration(existing, preview, :unchanged)
    elsif existing.status.in?(PORTAL_WINS_STATUSES)
      preview.previous_status = existing.status
      keep_registration(existing, preview, :kept)
    else
      preview.previous_status = existing.status
      count_registration(preview, :updated)
      existing.update!(status: status, skip_cancellation_emails: true) unless @dry_run
      existing
    end
  end

  def keep_registration(existing, preview, outcome)
    count_registration(preview, outcome)
    preview.status = existing.status
    existing
  end

  def count_registration(preview, outcome)
    preview.registration_status = outcome
    counter = :"registrations_#{outcome}"
    @result[counter] += 1
  end

  def build_registration(person, status)
    @event.event_registrations.create!(
      registrant: person, status: status, skip_cancellation_emails: true,
      created_by: @import_user, updated_by: @import_user
    )
  end

  # Says on the registration itself what the sheet claimed and why it wasn't
  # applied, so the difference is reviewable where the status lives rather than
  # only in the import preview. Matched on the body so a re-run adds nothing.
  def note_status_conflict(registration, preview)
    body = "Imported sheet said “#{status_label(preview.status_from_sheet)}”; kept this registration's " \
           "“#{status_label(registration.status)}”."
    return if registration.comments.exists?(topic: COMMENT_TOPIC, body: body)

    registration.comments.create_as_system!(topic: COMMENT_TOPIC, body: body)
  end

  # One registration standing for several people, said on the registration itself —
  # the others aren't named anywhere, so someone has to add them by hand.
  def note_seat_count(registration, values)
    count = seats(values)
    return if count < 2

    body = "Imported sheet says this registration covers #{count} people; only this one is named."
    return if registration.comments.exists?(topic: COMMENT_TOPIC, body: body)

    registration.comments.create_as_system!(topic: COMMENT_TOPIC, body: body)
  end

  # Whatever the sheet's own Notes and Comments say, kept on the registration they
  # describe rather than dropped. Matched on the body so a re-run adds nothing.
  def note_sheet_comments(registration, values)
    %i[notes comments].each do |field|
      body = values[field]
      next if body.blank? || registration.comments.exists?(topic: COMMENT_TOPIC, body: body)

      registration.comments.create_as_system!(topic: COMMENT_TOPIC, body: body)
    end
  end

  def status_label(status)
    EventRegistration::ATTENDANCE_STATUS_LABELS.fetch(status, status.to_s.humanize)
  end

  # Days, the yes/no flags, and dates: the sheet fills these in without clearing
  # anything already recorded. Days are left out when the sheet's status lost to
  # the portal's — they describe the outcome we just declined to overwrite, so
  # writing them would contradict the status that stands.
  def apply_registration_details(registration, values, apply_days:)
    attributes = {}
    if apply_days
      days = day_values(values)
      days = (1..@event.day_count).index_with { true } if days.empty? && registration.attended?
      attributes.merge!(day_attributes(days))
    end

    %i[someone_else_will_pay invoice_requested w9_requested].each do |flag|
      answer = Columns.yes_no(values[flag])
      attributes[flag] = answer unless answer.nil?
    end
    { post_survey_completed: :post_survey_completed_at, certificate_sent: :certificate_sent_at }.each do |field, column|
      at = completion_time(values[field])
      attributes[column] = at if at && registration[column].blank?
    end
    registered_on = Columns.date(values[:registered_on])
    attributes[:created_at] = registered_on.in_time_zone if registered_on && registration.previously_new_record?

    registration.update!(attributes) if attributes.any?
  end

  # A date cell is the moment itself; a bare "yes" stands for the event's last day,
  # read off the program-zone dates so it doesn't shift with the viewer.
  def completion_time(raw)
    answer = Columns.yes_no(raw)
    return if answer == false
    return (@event.ends_on || @event.starts_on)&.in_time_zone if answer

    Columns.date(raw)&.in_time_zone
  end

  # ── Organizations ───────────────────────────────────────────────────────

  def resolve_organization(name, preview)
    match = find_organization(name)
    if name.blank?
      preview.organization_status = :none
    elsif match
      @result.organizations_linked += 1
      preview.organization_status = match.basis == :exact ? :linked : :linked_by_spelling
      preview.organization_label = match.organization.name
    else
      @result.organizations_to_reconcile += 1
      preview.organization_status = :to_reconcile
    end
    match&.organization
  end

  def find_organization(name)
    return if name.blank?

    key = name.downcase
    return @organization_cache[key] if @organization_cache.key?(key)

    @organization_cache[key] = @organization_matcher.call(name)
  end

  # ── Answers ─────────────────────────────────────────────────────────────

  # field_identifier → value for everything the row says about the person and their
  # org, in the shape a submitted registration form would carry it.
  def build_answers(values, preview)
    answers = PLAIN_ANSWERS.each_with_object({}) do |(field, identifier), hash|
      hash[identifier] = values[field] if values[field]
    end
    answers["legal_first_name"] = values[:first_name] if values[:nickname]
    answers["organization_type"] = organization_type(values[:organization_type]) if values[:organization_type]
    answers["mailing_address_type"] = contact_type(values[:mailing_address_type])
    answers["phone_type"] = contact_type(values[:phone_type])
    answers["primary_sector"] = sector_ids(values[:primary_sector], preview, scope: Sector.published.excluding_other).first&.to_s
    answers["additional_sectors"] = sector_ids(values[:additional_sectors], preview, scope: Sector.published).map(&:to_s).presence
    answers["primary_age_group"] = age_group_ids(values[:primary_age_group], preview).first&.to_s
    answers["additional_age_groups"] = age_group_ids(values[:additional_age_groups], preview).map(&:to_s).presence
    translate_address_answers(answers, "mailing")
    translate_address_answers(answers, "organization")
    answers.compact
  end

  # The sheet's free-text state and country, as the registration form's dropdowns store them.
  def translate_address_answers(answers, prefix)
    state = answers["#{prefix}_state"]
    country = answers["#{prefix}_country"]
    return if state.blank? && country.blank?

    answers["#{prefix}_state"] = @address_translation.state(state, country:)
    answers["#{prefix}_country"] = @address_translation.country(country, state:)
  end

  def organization_type(raw)
    Organization::ORGANIZATION_TYPES.find { |type| type.casecmp?(raw) } || "Other: #{raw}"
  end

  def contact_type(raw)
    CONTACT_TYPES.find { |type| type.casecmp?(@address_translation.address_type(raw).to_s) }
  end

  def sector_ids(raw, preview, scope:)
    names_to_ids(raw, preview, "sector") { |names| scope.where(name: names).pluck(:name, :id) }
  end

  def age_group_ids(raw, preview)
    type = CategoryType.find_by(name: FormField::DYNAMIC_FIELD_CATEGORY_TYPES["primary_age_group"])
    names_to_ids(raw, preview, "age group") { |names| type ? type.categories.published.where(name: names).pluck(:name, :id) : [] }
  end

  def names_to_ids(raw, preview, label)
    names = Columns.list(raw)
    return [] if names.empty?

    found = yield(names).to_h { |name, id| [ name.downcase, id ] }
    names.filter_map do |name|
      found[name.downcase].tap { |id| preview.warnings << "Unknown #{label} “#{name}”" unless id }
    end
  end

  # ── Money & details preview ─────────────────────────────────────────────

  # Mirrors the order the real run applies money: the scholarship against the
  # registration, then the payment (registration, then CE), then a discount comping
  # whatever a paying row still owes.
  def set_money_preview(values, preview)
    registration_cost = @event.cost_cents.to_i
    ce_cost = ce_requested?(values) && @event.ce_eligible? ? @event.ce_hours_cost_cents.to_i : 0

    scholarship = parse_cents(values[:scholarship_amount]).to_i
    if scholarship.positive? && registration_cost.positive?
      preview.scholarship_cents = [ scholarship, registration_cost ].min
      @result.scholarships_recorded += 1
      @result.scholarships_amount_cents += preview.scholarship_cents
    end

    return if values[:amount_paid].blank?

    cents = parse_cents(values[:amount_paid])
    return preview.payment_status = :invalid if cents.nil? || cents <= 0

    preview.payment_amount_cents = cents
    payment_class = payment_class_for(values[:payment_type])
    if payment_class.nil?
      preview.payment_label = values[:payment_type]
      return preview.payment_status = :unknown_type
    end
    return preview.payment_status = :missing_check_number if payment_class == CheckPayment && values[:check_number].blank?

    return preview.payment_status = :free if registration_cost + ce_cost <= 0

    owed = registration_cost + ce_cost - preview.scholarship_cents.to_i
    return preview.payment_status = :nothing_owed if owed <= 0

    preview.payment_status = :will_record
    preview.payment_label = PAYMENT_TYPE_LABELS[payment_class.name]
    preview.owed_cents = owed
    preview.bulk_ref = bulk_ref(values, payment_class)
  end

  # Rows that name the same BulkPayment reference were paid together; so were check
  # rows carrying one check number. Anything else is its own payment.
  def bulk_ref(values, payment_class)
    return "ref:#{values[:bulk_payment].downcase}" if values[:bulk_payment]
    return "check:#{values[:check_number]}" if payment_class == CheckPayment && values[:check_number]

    nil
  end

  # One row's money intent, held until every row is read. Keyed by the payment it
  # belongs to, so a batch is one payment and a plain row is a batch of one.
  def record_payment_intent(person, registration, values, preview)
    key = preview.bulk_ref || "row:#{preview.number}"
    @payment_batches[key] ||= []
    @payment_batches[key] << {
      person: person, registration: registration, values: values, preview: preview,
      cents: parse_cents(values[:amount_paid]).to_i,
      payment_class: payment_class_for(values[:payment_type]), check_number: values[:check_number]
    }
  end

  # The batch's payment, then its split. Rows of a group may each carry the whole
  # amount or each carry a share; what separates them is the cost they answer to,
  # so an amount that covers the group's whole bill is read as the one payment and
  # anything less as a share of it. Either way nobody is allocated more than their
  # own registration costs, and whatever the payment leaves unpaid is comped.
  def apply_payment_batch(members)
    owed = members.sum { |member| member[:preview].owed_cents.to_i }
    amounts = members.map { |member| member[:cents] }
    total = amounts.uniq.one? && amounts.first >= owed ? amounts.first : amounts.sum

    @result.payments_recorded += 1
    @result.payments_amount_cents += total
    unless @dry_run
      submission = bulk_payment_submission(members) if attendee_count(members) > 1
      payment = resolve_payment(members, total, submission)
    end

    remaining = total
    members.each do |member|
      preview = member[:preview]
      share = [ remaining, preview.owed_cents.to_i ].min
      remaining -= share
      preview.payment_amount_cents = share
      preview.payment_total_cents = total
      preview.bulk_size = attendee_count(members) if attendee_count(members) > 1
      allocate_share(member, payment, share) unless @dry_run
      record_discount(preview, preview.owed_cents.to_i - share)
    end

    return if @dry_run

    members.each do |member|
      payables_for(member[:registration], member[:values]).each { |payable| cover_remainder_with_discount(payable) }
      submission&.link_registration!(member[:registration].id)
    end
  end

  # The event's bulk payments page lists role "bulk_payment" submissions, so a group
  # payment needs one to appear there beside the payer-submitted ones.
  def bulk_payment_submission(members)
    form = bulk_payment_form
    payer = batch_payer(members)
    ref = members.first[:preview].bulk_ref
    submission = @event.form_submissions
      .where(form: form, role: "bulk_payment")
      .detect { |candidate| candidate.metadata&.[](BULK_REF_KEY) == ref }
    submission ||= FormSubmission.create!(
      person: payer.is_a?(Person) ? payer : nil, form: form, event: @event, role: "bulk_payment",
      metadata: { IMPORT_SOURCE_KEY => @source, BULK_REF_KEY => ref }.compact
    )
    persist_bulk_answers(submission, form, members, payer)
    submission
  end

  # Attaches the bulk payment form an admin would have picked for this event
  # (Form.standalone, the same scope the event form picker offers), creating one
  # only when the install has none.
  def bulk_payment_form
    return @bulk_payment_form if defined?(@bulk_payment_form)

    @bulk_payment_form = @event.bulk_payment_form || attach_bulk_payment_form
  end

  def attach_bulk_payment_form
    form = Form.standalone.where(role: "bulk_payment").order(:id).first ||
      Form.create!(name: BULK_PAYMENT_FORM_NAME, role: "bulk_payment",
                   created_by: @import_user, updated_by: @import_user)
    @event.event_forms.create!(form: form, role: "bulk_payment")
    form
  end

  # Who paid and who they paid for, in the shape the bulk payment card reads
  # (FormSubmissionDecorator#matched_attendees). Only the questions this form asks
  # are recorded.
  def persist_bulk_answers(submission, form, members, payer)
    answers = {
      "bulk_payment_attendees" => bulk_attendees(members).to_json,
      "number_of_attendees" => attendee_count(members).to_s,
      "organization_name" => payer.is_a?(Organization) ? payer.name : nil,
      "first_name" => payer.try(:first_name), "last_name" => payer.try(:last_name),
      "primary_email" => payer.try(:email)
    }.compact
    answers.each do |identifier, value|
      field = form.form_fields.find_by(field_identifier: identifier)
      submission.persist_answer(field, value) if field
    end
  end

  def attendee_count(members)
    members.sum { |member| seats(member[:values]) }
  end

  # Everyone the payment covers: the rows that named someone, then a placeholder per
  # head the sheet counted without naming.
  def bulk_attendees(members)
    named = members.map do |member|
      values = member[:values]
      { "first_name" => values[:first_name], "last_name" => values[:last_name], "email" => values[:email] }.compact
    end
    named + Array.new(attendee_count(members) - named.size) { UNNAMED_ATTENDEE }
  end

  def record_discount(preview, discount)
    return unless discount.positive?

    preview.discount_cents = discount
    @result.discounts_recorded += 1
    @result.discounts_amount_cents += discount
  end

  # Spreads one member's share over their registration and then its CE, each capped
  # at what it still owes, so a re-run adds nothing.
  def allocate_share(member, payment, share)
    payables_for(member[:registration], member[:values]).each do |payable|
      to_allocate = [ share, payable.remaining_cost ].min
      next unless to_allocate.positive?

      payable.allocations.find_or_create_by!(source: payment) { |allocation| allocation.amount = to_allocate }
      share -= to_allocate
    end
  end

  def set_detail_preview(values, answers, preview)
    preview.details << "Mailing address" if answers["mailing_city"]
    preview.details << "Phone" if answers["phone"]
    preview.details << "Org address" if answers["organization_city"]
    preview.details << "Position" if answers["organization_position"]
    preview.details << "Sectors" if answers["primary_sector"] || answers["additional_sectors"]
    preview.details << "Age groups" if answers["primary_age_group"] || answers["additional_age_groups"]
    preview.details << "Registered #{Columns.date(values[:registered_on]).strftime("%-m/%-d/%Y")}" if Columns.date(values[:registered_on])
    preview.details << "Notes" if values[:notes] || values[:comments]
    if seats(values) > 1
      preview.warnings << "Covers #{seats(values)} people — only this one is named, " \
                          "so the rest need adding and linking on the bulk payments page"
    end
    if preview.registration_status == :kept && day_values(values).any?
      preview.warnings << "Day columns not applied — the registration keeps its own status"
    end

    return unless ce_requested?(values)

    if @event.ce_eligible?
      preview.ce_status = :will_enroll
      preview.details << "CE"
      @result.ce_enrollments += 1
      ce_cost = @event.ce_hours_cost_cents.to_i
      if ce_cost.positive? && preview.payment_status != :will_record
        preview.warnings << "CE stays unpaid (#{MoneyFormatter.dollars_from_cents(ce_cost)}) — no CE certificate until it's paid"
      end
    else
      preview.ce_status = :not_offered
      preview.warnings << "CE requested, but this event offers no CE hours"
    end
  end

  # How many people the row stands for. FileMaker kept one registration for a group
  # and counted the heads, so the row names one of them at most.
  def seats(values)
    [ values[:person_count].to_i, 1 ].max
  end

  def ce_requested?(values)
    Columns.requested?(values[:ce_requested])
  end

  # ── Persisting ──────────────────────────────────────────────────────────

  def persist_registration(person, registration, values, organization, answers, preview)
    newly_created = person.previously_new_record?
    status_kept = preview.registration_status == :kept
    note_status_conflict(registration, preview) if status_kept
    note_seat_count(registration, values)
    note_sheet_comments(registration, values)
    apply_registration_details(registration, values, apply_days: !status_kept)
    submission = import_submission(person, answers)
    capture_organization(person, registration, submission, organization, answers, preview)
    capture_person(person, answers, preview, overwrite: newly_created)
    enroll_ce(registration, values) if preview.ce_status == :will_enroll
    apply_scholarship(person, registration, values)
  end

  # Fill-only mode keeps what the portal already holds. Whatever it declined is
  # reported on the row and written to the person as a comment, so a curated sheet's
  # value is reviewable rather than dropped.
  def capture_person(person, answers, preview, overwrite:)
    capture = PersonServices::CaptureFromSubmission.new(person: person, answers: answers, overwrite: overwrite)
    capture.call
    note_declined(person, capture.declined.map { |d| [ d.attribute.to_s.humanize, d.submitted, d.saved ] }, preview)
  end

  def note_declined(record, entries, preview)
    entries.each { |label, submitted, saved| preview.warnings << "Kept #{label.downcase} “#{saved}” — sheet said “#{submitted}”" }
    return if entries.empty?

    body = "Imported sheet disagreed and was not applied: " +
      entries.map { |label, submitted, saved| "#{label} “#{submitted}” (kept “#{saved}”)" }.join("; ") + "."
    return if record.comments.exists?(topic: COMMENT_TOPIC, body: body)

    record.comments.create_as_system!(topic: COMMENT_TOPIC, body: body)
  end

  def capture_organization(person, registration, submission, organization, answers, preview)
    return unless organization

    note_declined(organization, organization_declines(organization, answers), preview)
    result = OrganizationServices::CaptureFromSubmission.call(
      person: person, answers: answers, organization: organization, submission: submission,
      facilitator_training: @event.facilitator_training, training_date: @event.start_date,
      event_registration: registration, overwrite: false
    )
    registration.link_submitted_organization!(organization, submission: submission, autofill: result.autofill)
  end

  # The org answers fill-blanks won't apply, from the comparison the link-organization
  # flow already uses.
  def organization_declines(organization, answers)
    OrganizationServices::ProfileDiff.for_entry(organization: organization, entry: FormSubmission.org_entry_from(answers))
      .map { |discrepancy| [ discrepancy.label, discrepancy.submitted, discrepancy.saved ] }
  end

  def enroll_ce(registration, values)
    ContinuingEducationRegistration.enroll!(
      event_registration: registration,
      number: values[:license_number], kind: values[:license_kind],
      issuing_state: values[:license_issuing_state], expires_on: Columns.date(values[:license_expires_on])
    )
  end

  # An accepted award — the training already happened — capped at what the
  # registration costs. A registration that already carries a scholarship keeps it.
  def apply_scholarship(person, registration, values)
    cents = parse_cents(values[:scholarship_amount]).to_i
    return unless cents.positive?
    return if registration.scholarships.exists?

    amount = [ cents, registration.remaining_cost ].min
    return unless amount.positive?

    scholarship = Scholarship.new(
      recipient: person, amount_cents: amount, agreement_response_status: "accepted",
      created_by: @import_user, updated_by: @import_user
    )
    scholarship.build_allocation(allocatable: registration, amount: amount)
    scholarship.save!
    registration.allocations.reset
  end

  # What this row is about. A CE registration the sheet never mentions is a live
  # balance someone else is still expected to pay, so the import leaves it alone
  # rather than spending the row's money on it or comping it away.
  def import_payment?(candidate, ref)
    metadata = candidate.metadata
    return false unless metadata&.[](IMPORT_SOURCE_KEY).present?
    return false unless metadata["event_id"] == @event.id

    metadata[BULK_REF_KEY] == ref
  end

  # Who the payment is recorded against. One organization behind every row of a
  # batch is the payer we can name; otherwise the batch's first registrant stands
  # for it, since a payment needs a person or an organization.
  def batch_payer(members)
    organizations = members.map { |member| @organization_cache[member[:values][:organization]&.downcase]&.organization }
    shared = organizations.uniq
    return shared.first if members.size > 1 && shared.one? && shared.first

    members.first[:person]
  end

  def payables_for(registration, values)
    return [ registration ] unless ce_requested?(values)

    [ registration, *registration.continuing_education_registrations.reload ]
  end

  # Comps whatever the payment didn't cover so a partial amount still reads as
  # "Paid". A re-run sees nothing left to cover and adds no second discount.
  def cover_remainder_with_discount(payable)
    payable.allocations.reset
    remaining = payable.remaining_cost
    return unless remaining.positive?

    discount = Discount.new(amount_cents: remaining, event: @event)
    discount.created_by = @import_user if discount.respond_to?(:created_by=)
    discount.updated_by = @import_user if discount.respond_to?(:updated_by=)
    discount.save!
    payable.allocations.create!(source: discount, amount: remaining)
  end

  # Reuses our own prior import payment for this batch on this event (keyed by the
  # import metadata), so re-running never mints duplicates and imports into other
  # events never steal each other's money; otherwise creates one. A batch of
  # several is paid by the organization they share, else by its first registrant.
  def resolve_payment(members, cents, submission = nil)
    payment_class = members.first[:payment_class]
    ref = members.first[:preview].bulk_ref
    payer = batch_payer(members)
    existing = payment_class
      .where(amount_cents: cents)
      .where(ref ? {} : { person_id: payer.is_a?(Person) ? payer.id : nil })
      .detect { |candidate| import_payment?(candidate, ref) }
    return existing if existing

    payment = payment_class.new(
      amount_cents: cents, currency: "usd",
      metadata: {
        IMPORT_SOURCE_KEY => @source, "event_id" => @event.id, BULK_REF_KEY => ref,
        "name" => payer.try(:full_name) || payer.name, "email" => payer.try(:email)
      }.compact
    )
    payer.is_a?(Organization) ? payment.organization = payer : payment.person = payer
    payment.form_submission = submission
    payment.check_number = members.first[:check_number] if payment_class == CheckPayment
    payment.skip_pay_charge_validation = true if payment.respond_to?(:skip_pay_charge_validation=)
    payment.created_by = @import_user if payment.respond_to?(:created_by=)
    payment.updated_by = @import_user if payment.respond_to?(:updated_by=)
    payment.save!
    payment
  end

  # The import's OWN registration submission — created alongside, never in place
  # of, a real registrant's. Found only among import-marked submissions, so a
  # genuine submission is left untouched; re-running the same import reuses (and
  # re-saves) this one rather than piling up duplicates. Only the questions this
  # event's form asks are recorded; the rest still reach the person and org.
  def import_submission(person, answers)
    submission = person.form_submissions
      .where(form: @registration_form, event: @event, role: "registration")
      .detect { |candidate| candidate.metadata&.key?(IMPORT_SOURCE_KEY) }
    submission ||= FormSubmission.create!(
      person: person, form: @registration_form, event: @event, role: "registration",
      metadata: { IMPORT_SOURCE_KEY => @source }
    )
    answers.each do |identifier, value|
      field = form_field_for(identifier)
      submission.persist_answer(field, value) if field
    end
    submission
  end

  def form_field_for(identifier)
    return @form_field_cache[identifier] if @form_field_cache.key?(identifier)

    @form_field_cache[identifier] =
      @registration_form.form_fields.find_by(field_identifier: identifier)
  end

  def skip(preview, reason)
    preview.skipped_reason = reason
    @result.skipped << preview
    @result.rows << preview
    nil
  end

  def clean(value)
    value.to_s.strip.presence
  end

  def payment_class_for(raw)
    return DEFAULT_PAYMENT_TYPE if raw.blank?

    PAYMENT_TYPES[Columns.compact(raw)]
  end

  # Parses a money cell ("$1,099.00", "10.99", "10") to integer cents; nil on junk.
  def parse_cents(raw)
    cleaned = raw.to_s.gsub(/[^0-9.\-]/, "")
    return nil if cleaned.blank?

    (BigDecimal(cleaned) * 100).round
  rescue ArgumentError
    nil
  end
end
