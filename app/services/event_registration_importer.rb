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
#   * EventRegistration — the Status column (Attended when blank, or derived from
#     Day N columns when only those are filled). An active registration takes the
#     row's status; a cancelled / no-show / transferred-out one is never overwritten
#     — the row adds a second registration beside it (Data health lists these).
#     Attended marks every day complete unless Day N columns say otherwise.
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
#     CE), then a Discount comping whatever a paying row still owes, so it reads Paid.
#
# No emails are sent and no mailing-list subscription is made. Runs in a
# transaction with a dry_run mode that rolls back for the preview.
class EventRegistrationImporter
  DEFAULT_STATUS = "attended".freeze

  # metadata key stamped on the submission the import creates, so we can find our
  # own submission on a re-run (idempotency) without ever matching a real one.
  IMPORT_SOURCE_KEY = "imported_from".freeze

  PLACEHOLDER_EMAIL_DOMAIN = "example.com".freeze
  PLACEHOLDER_EMAIL = /\A(\d+)@example\.com\z/

  # Row field → registration-form field_identifier for the answers that pass through
  # unchanged; sectors, age groups, and the org/contact types are resolved first.
  PLAIN_ANSWERS = {
    first_name: "first_name",
    last_name: "last_name",
    email: "primary_email",
    nickname: "nickname",
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
    :registrations_created, :registrations_added_alongside, :registrations_updated, :registrations_unchanged,
    :organizations_linked, :organizations_to_reconcile,
    :payments_recorded, :payments_amount_cents,
    :scholarships_recorded, :scholarships_amount_cents,
    :discounts_recorded, :discounts_amount_cents,
    :ce_enrollments, :unrecognized_headers,
    :skipped, :rows,
    keyword_init: true
  ) do
    def registrations_total
      registrations_created + registrations_added_alongside + registrations_updated + registrations_unchanged
    end

    def summary
      [
        "rows processed: #{rows_processed}",
        "people matched: #{people_matched} (#{people_matched_by_name} by name), created: #{people_created} " \
          "(#{placeholder_emails} with a placeholder email)",
        "registrations created: #{registrations_created}, added beside an inactive one: #{registrations_added_alongside}, " \
          "status updated: #{registrations_updated}, unchanged: #{registrations_unchanged}",
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
    :status, :registration_status, :previous_status,
    :organization_status, :organization_label,
    :payment_status, :payment_label, :payment_amount_cents, :discount_cents,
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
      registrations_created: 0, registrations_added_alongside: 0, registrations_updated: 0, registrations_unchanged: 0,
      organizations_linked: 0, organizations_to_reconcile: 0,
      payments_recorded: 0, payments_amount_cents: 0,
      scholarships_recorded: 0, scholarships_amount_cents: 0,
      discounts_recorded: 0, discounts_amount_cents: 0,
      ce_enrollments: 0, unrecognized_headers: [],
      skipped: [], rows: []
    )
    @organization_matcher = OrganizationServices::NameMatcher.new
    @organization_cache = {}
    @form_field_cache = {}
    @seen_row_keys = {}
  end

  def call
    ActiveRecord::Base.transaction do
      each_row { |row, number| process_row(row, number) }
      raise ActiveRecord::Rollback if @dry_run
    end
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

    missing = [ [ "first name", values[:first_name] ], [ "last name", values[:last_name] ] ]
      .select { |_label, value| value.blank? }.map(&:first)
    return skip(preview, "missing #{missing.join(", ")}") if missing.any?

    status = resolve_status(values)
    return skip(preview, "unknown status “#{values[:status]}”") if status == :invalid

    key = row_key(values)
    return skip(preview, "duplicate of row #{@seen_row_keys[key]} in this file") if @seen_row_keys.key?(key)
    @seen_row_keys[key] = number

    preview.status = status
    organization = resolve_organization(values[:organization], preview)
    person = resolve_person(values, organization, preview)
    registration = resolve_registration(person, status, preview)
    answers = build_answers(values, preview)
    set_money_preview(values, preview)
    set_detail_preview(values, answers, preview)

    persist_registration(person, registration, values, organization, answers, preview) unless @dry_run

    @result.rows << preview
  end

  def row_key(values)
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

  def resolve_person(values, organization, preview)
    existing, basis = find_matching_person(values, organization)
    if existing
      @result.people_matched += 1
      @result.people_matched_by_name += 1 if basis
      preview.person_status = basis ? :"matched_by_#{basis}" : :matched
      preview.person_label = existing.full_name
      return existing
    end

    @result.people_created += 1
    preview.person_status = :new
    preview.person_label = "#{values[:first_name]} #{values[:last_name]}"
    email = values[:email] || placeholder_email(preview)
    person = Person.new(
      first_name: values[:first_name], last_name: values[:last_name], email: email,
      created_by: @import_user, updated_by: @import_user
    )
    person.save! unless @dry_run
    person
  end

  def find_matching_person(values, organization)
    if values[:email]
      person = PersonMatcher.call(email: values[:email], last_name: values[:last_name], first_names: [ values[:first_name] ])
      return [ person, nil ]
    end

    match = PersonNameMatcher.call(first_name: values[:first_name], last_name: values[:last_name], organization: organization)
    [ match.person, match.basis ]
  end

  # The lowest N@example.com no person or login holds yet (nor an earlier row of
  # this file), so an email-less registrant still has a unique address on file.
  def placeholder_email(preview)
    @placeholder_numbers ||= taken_placeholder_numbers
    number = 1
    number += 1 while @placeholder_numbers.include?(number)
    @placeholder_numbers << number
    @result.placeholder_emails += 1
    preview.placeholder_email = "#{number}@#{PLACEHOLDER_EMAIL_DOMAIN}"
  end

  def taken_placeholder_numbers
    pattern = "%@#{PLACEHOLDER_EMAIL_DOMAIN}"
    emails = Person.where("email LIKE :p OR email_2 LIKE :p", p: pattern).pluck(:email, :email_2).flatten +
      User.where("email LIKE ?", pattern).pluck(:email)
    emails.filter_map { |email| email.to_s.downcase[PLACEHOLDER_EMAIL, 1]&.to_i }.to_set
  end

  # ── Registrations ───────────────────────────────────────────────────────

  def resolve_registration(person, status, preview)
    existing = @event.event_registrations.active_first.find_by(registrant: person) unless person.new_record?

    if existing.nil?
      count_registration(preview, :created)
      return if @dry_run

      build_registration(person, status)
    elsif existing.inactive?
      preview.previous_status = existing.status
      return keep_registration(existing, preview) if status.in?(EventRegistration::INACTIVE_STATUSES)

      count_registration(preview, :added_alongside)
      return if @dry_run

      build_registration(person, status)
    elsif existing.status == status
      keep_registration(existing, preview)
    else
      preview.previous_status = existing.status
      count_registration(preview, :updated)
      existing.update!(status: status, skip_cancellation_emails: true) unless @dry_run
      existing
    end
  end

  def keep_registration(existing, preview)
    count_registration(preview, :unchanged)
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

  # Days, the yes/no flags, and dates: the sheet fills these in without clearing
  # anything already recorded.
  def apply_registration_details(registration, values)
    attributes = {}
    days = day_values(values)
    days = (1..@event.day_count).index_with { true } if days.empty? && registration.attended?
    attributes.merge!(day_attributes(days))

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

  # A date cell is the moment itself; a bare "yes" stands for the event's last day.
  def completion_time(raw)
    answer = Columns.yes_no(raw)
    return if answer == false
    return (@event.end_date.presence || @event.start_date)&.to_date&.in_time_zone if answer

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
    answers["organization_type"] = organization_type(values[:organization_type]) if values[:organization_type]
    answers["mailing_address_type"] = contact_type(values[:mailing_address_type])
    answers["phone_type"] = contact_type(values[:phone_type])
    answers["primary_sector"] = sector_ids(values[:primary_sector], preview, scope: Sector.published.excluding_other).first&.to_s
    answers["additional_sectors"] = sector_ids(values[:additional_sectors], preview, scope: Sector.published).map(&:to_s).presence
    answers["primary_age_group"] = age_group_ids(values[:primary_age_group], preview).first&.to_s
    answers["additional_age_groups"] = age_group_ids(values[:additional_age_groups], preview).map(&:to_s).presence
    answers.compact
  end

  def organization_type(raw)
    Organization::ORGANIZATION_TYPES.find { |type| type.casecmp?(raw) } || "Other: #{raw}"
  end

  def contact_type(raw)
    CONTACT_TYPES.find { |type| type.casecmp?(raw.to_s) }
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

    owed = registration_cost + ce_cost - preview.scholarship_cents.to_i
    return preview.payment_status = :free if registration_cost + ce_cost <= 0

    preview.payment_status = :will_record
    preview.payment_label = PAYMENT_TYPE_LABELS[payment_class.name]
    applied = [ cents, owed ].min
    @result.payments_recorded += 1
    @result.payments_amount_cents += applied

    discount = owed - applied
    return unless discount.positive?

    preview.discount_cents = discount
    @result.discounts_recorded += 1
    @result.discounts_amount_cents += discount
  end

  def set_detail_preview(values, answers, preview)
    preview.details << "Mailing address" if answers["mailing_city"]
    preview.details << "Phone" if answers["phone"]
    preview.details << "Org address" if answers["organization_city"]
    preview.details << "Position" if answers["organization_position"]
    preview.details << "Sectors" if answers["primary_sector"] || answers["additional_sectors"]
    preview.details << "Age groups" if answers["primary_age_group"] || answers["additional_age_groups"]
    preview.details << "Registered #{Columns.date(values[:registered_on]).strftime("%-m/%-d/%Y")}" if Columns.date(values[:registered_on])

    return unless ce_requested?(values)

    if @event.ce_eligible?
      preview.ce_status = :will_enroll
      preview.details << "CE"
      @result.ce_enrollments += 1
    else
      preview.ce_status = :not_offered
      preview.warnings << "CE requested, but this event offers no CE hours"
    end
  end

  def ce_requested?(values)
    Columns.yes_no(values[:ce_requested]) == true
  end

  # ── Persisting ──────────────────────────────────────────────────────────

  def persist_registration(person, registration, values, organization, answers, preview)
    newly_created = person.previously_new_record?
    apply_registration_details(registration, values)
    submission = import_submission(person, answers)
    capture_organization(person, registration, submission, organization, answers)
    PersonServices::CaptureFromSubmission.call(person: person, answers: answers, overwrite: newly_created)
    enroll_ce(registration, values) if preview.ce_status == :will_enroll
    apply_scholarship(person, registration, values)
    apply_payment(person, registration, values)
  end

  def capture_organization(person, registration, submission, organization, answers)
    return unless organization

    result = OrganizationServices::CaptureFromSubmission.call(
      person: person, answers: answers, organization: organization, submission: submission,
      facilitator_training: @event.facilitator_training, training_date: @event.start_date,
      event_registration: registration, overwrite: false
    )
    link = registration.event_registration_organizations.find_or_create_by!(organization: organization)
    # Only pin our submission on a link we created — an org a real registrant
    # already linked keeps its own pin.
    return unless link.previously_new_record?

    link.record_form_submission(submission)
    link.record_autofill(result.autofill)
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

  # Applies the row's AmountPaid by finding-or-creating a payment and allocating it
  # to the registration, then its CE, each capped at what it still owes — so a
  # re-run adds nothing and a fully-covered amount reads as "Paid".
  def apply_payment(person, registration, values)
    cents = parse_cents(values[:amount_paid])
    return if cents.nil? || cents <= 0

    payment_class = payment_class_for(values[:payment_type])
    return if payment_class.nil?
    return if payment_class == CheckPayment && values[:check_number].blank?

    payment = nil
    remaining = cents
    payables(registration).each do |payable|
      to_allocate = [ remaining, payable.remaining_cost ].min
      next unless to_allocate.positive?

      payment ||= resolve_payment(person, cents, payment_class, values[:check_number])
      payable.allocations.find_or_create_by!(source: payment) { |allocation| allocation.amount = to_allocate }
      remaining -= to_allocate
    end

    payables(registration).each { |payable| cover_remainder_with_discount(payable) }
  end

  def payables(registration)
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

  # Reuses our own prior import payment for this person + amount + type on this
  # event (keyed by the import metadata), so re-running never mints duplicates and
  # imports into other events never steal each other's money; otherwise creates one.
  def resolve_payment(person, cents, payment_class, check_number)
    existing = payment_class
      .where(person_id: person.id, amount_cents: cents)
      .detect { |candidate| candidate.metadata&.[](IMPORT_SOURCE_KEY).present? && candidate.metadata["event_id"] == @event.id }
    return existing if existing

    payment = payment_class.new(
      person: person, amount_cents: cents, currency: "usd",
      metadata: { IMPORT_SOURCE_KEY => @source, "event_id" => @event.id, "name" => person.full_name, "email" => person.email }
    )
    payment.check_number = check_number if payment_class == CheckPayment
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
