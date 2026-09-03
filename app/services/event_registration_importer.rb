require "csv"
require "bigdecimal"

# Bulk-imports event registrants into one existing event from an uploaded CSV
# (columns FirstName, LastName, Organization, EMail). Every row is treated as
# someone who ATTENDED, so it simulates the registration a real submission would
# create and then lets the same reconciliation flow take over:
#
#   * Person — matched (never duplicated) on the PublicRegistration rule
#     (email + last name, tolerant of a first-name/legal-name swap); created,
#     attributed to the importing admin, only on a miss.
#   * EventRegistration — found or created, forced to "attended" (a real
#     submission would be "registered"; these people already attended).
#   * FormSubmission (role "registration") + FormAnswers for the name, email and
#     organization the row carries — the import's OWN submission, marked
#     `imported_from` in metadata and created alongside (never in place of) a real
#     registrant's submission, so genuine answers are left untouched and the
#     import's data is never dropped. This is what makes an unmatched organization
#     appear in the admin "link organization" reconciliation queue like a live reg.
#   * Organization — matched by name → linked to the registration (pinned to the
#     submission) and, on a facilitator-training event, a "Facilitator" affiliation
#     is minted (AffiliationServices::CreateFromRegistration). An unmatched name is
#     left for reconciliation; it is never invented here.
#   * Payment — only when the row carries an AmountPaid. Finds (its own prior
#     import payment for this person + amount + type on this event, keyed by
#     metadata) or creates one, then finds-or-creates an Allocation applying it to
#     the registration, capped at the registration's remaining cost. PaymentType
#     picks the payment kind (cash / check / card, defaulting to cash); a free
#     event ignores the amount, since there's nothing to allocate against.
#   * Discount — the gap between the event cost and what was actually paid is
#     comped with a Discount allocation, so a partial AmountPaid (e.g. $50 on a
#     $750 event) still reads as "Paid". A full payment leaves no discount.
#
# No emails are sent, no mailing-list subscription, tags, addresses, or CE are
# created — the sheet carries none of that, and this is a historical backfill.
# Runs in a transaction with a dry_run mode that rolls back for the preview.
class EventRegistrationImporter
  IMPORTED_STATUS = "attended".freeze

  # Registration-form field_identifier → row field, mirrored into the submission's answers.
  ANSWER_IDENTIFIERS = {
    "first_name" => :first_name,
    "last_name" => :last_name,
    "primary_email" => :email,
    "organization_name" => :organization
  }.freeze

  ORGANIZATION_NAME_IDENTIFIER = "organization_name".freeze

  # metadata key stamped on the submission the import creates, so we can find our
  # own submission on a re-run (idempotency) without ever matching a real one.
  IMPORT_SOURCE_KEY = "imported_from".freeze

  # Keys are normalized header labels (see #normalize_header) → the field they map to.
  HEADER_ALIASES = {
    "firstname" => :first_name,
    "first name" => :first_name,
    "lastname" => :last_name,
    "last name" => :last_name,
    "name" => :last_name,
    "organization" => :organization,
    "organisation" => :organization,
    "org" => :organization,
    "email" => :email,
    "e-mail" => :email,
    "email address" => :email,
    "amount" => :amount_paid,
    "amount paid" => :amount_paid,
    "amount_paid" => :amount_paid,
    "amountpaid" => :amount_paid,
    "paid" => :amount_paid,
    "payment amount" => :amount_paid,
    "payment_amount" => :amount_paid,
    "type" => :payment_type,
    "method" => :payment_type,
    "payment type" => :payment_type,
    "payment_type" => :payment_type,
    "paymenttype" => :payment_type,
    "payment method" => :payment_type,
    "payment_method" => :payment_type,
    "check number" => :check_number,
    "check_number" => :check_number,
    "checknumber" => :check_number,
    "check #" => :check_number,
    "check no" => :check_number,
    "check_no" => :check_number,
    "checkno" => :check_number
  }.freeze

  # Normalized PaymentType token → the STI Payment subclass to create. A blank
  # type on a row carrying an amount falls back to cash; an unrecognized token
  # records no payment (surfaced in the preview) rather than guessing.
  PAYMENT_TYPES = {
    "cash" => CashPayment,
    "check" => CheckPayment,
    "cheque" => CheckPayment,
    "card" => ExternalProcessorPayment,
    "credit" => ExternalProcessorPayment,
    "credit card" => ExternalProcessorPayment,
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

    form.form_fields.exists?(field_identifier: ORGANIZATION_NAME_IDENTIFIER)
  end

  Result = Struct.new(
    :rows_processed, :people_created, :people_matched,
    :registrations_created, :registrations_promoted, :registrations_already_attended,
    :organizations_linked, :organizations_to_reconcile,
    :payments_recorded, :payments_amount_cents,
    :discounts_recorded, :discounts_amount_cents,
    :skipped, :rows,
    keyword_init: true
  ) do
    def registrations_total
      registrations_created + registrations_promoted + registrations_already_attended
    end

    def summary
      [
        "rows processed: #{rows_processed}",
        "people matched: #{people_matched}, created: #{people_created}",
        "registrations created: #{registrations_created}, promoted to attended: #{registrations_promoted}, " \
          "already attended: #{registrations_already_attended}",
        "organizations linked: #{organizations_linked}, to reconcile: #{organizations_to_reconcile}",
        "payments recorded: #{payments_recorded} (#{MoneyFormatter.dollars_from_cents(payments_amount_cents)})",
        "discounts recorded: #{discounts_recorded} (#{MoneyFormatter.dollars_from_cents(discounts_amount_cents)})",
        "skipped: #{skipped.size}"
      ].join("\n")
    end
  end

  # One row's preview outcome; the *_status symbols render as badges in the view.
  RowPreview = Struct.new(
    :number, :first_name, :last_name, :email, :organization_name,
    :person_status, :person_label,
    :registration_status, :organization_status,
    :payment_status, :payment_label, :payment_amount_cents, :discount_cents,
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
      rows_processed: 0, people_created: 0, people_matched: 0,
      registrations_created: 0, registrations_promoted: 0, registrations_already_attended: 0,
      organizations_linked: 0, organizations_to_reconcile: 0,
      payments_recorded: 0, payments_amount_cents: 0,
      discounts_recorded: 0, discounts_amount_cents: 0,
      skipped: [], rows: []
    )
    @organization_cache = {}
    @form_field_cache = {}
    @seen_person_keys = {}
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
        header = values.map { |label| HEADER_ALIASES[normalize_header(label)] }
        next
      end
      next if values.all?(&:blank?)

      number += 1
      yield header.zip(values).to_h, number
    end
  end

  def normalize_header(label)
    label.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def process_row(row, number)
    @result.rows_processed += 1
    values = {
      first_name: clean(row[:first_name]),
      last_name: clean(row[:last_name]),
      email: clean(row[:email])&.downcase,
      organization: clean(row[:organization]),
      amount_paid: clean(row[:amount_paid]),
      payment_type: clean(row[:payment_type]),
      check_number: clean(row[:check_number])
    }
    preview = RowPreview.new(
      number: number, first_name: values[:first_name], last_name: values[:last_name],
      email: values[:email], organization_name: values[:organization]
    )

    missing = missing_required(values)
    return skip(preview, "missing #{missing.join(", ")}") if missing.any?

    key = "#{values[:email]} #{values[:last_name].downcase}"
    if @seen_person_keys.key?(key)
      return skip(preview, "duplicate of row #{@seen_person_keys[key]} in this file")
    end
    @seen_person_keys[key] = number

    person = resolve_person(values, preview)
    registration = resolve_registration(person, preview)
    set_organization_preview(values[:organization], preview)
    set_payment_preview(values, preview)

    persist_registration(person, registration, values) unless @dry_run

    @result.rows << preview
  end

  def missing_required(values)
    [
      [ "first name", values[:first_name] ], [ "last name", values[:last_name] ], [ "email", values[:email] ]
    ].select { |_label, value| value.blank? }.map(&:first)
  end

  def resolve_person(values, preview)
    existing = find_matching_person(values)
    if existing
      @result.people_matched += 1
      preview.person_status = :matched
      preview.person_label = existing.full_name
      return existing
    end

    @result.people_created += 1
    preview.person_status = :new
    preview.person_label = "#{values[:first_name]} #{values[:last_name]}"
    person = Person.new(
      first_name: values[:first_name], last_name: values[:last_name], email: values[:email],
      created_by: @import_user, updated_by: @import_user
    )
    person.save! unless @dry_run
    person
  end

  # PublicRegistration's rule, so imports dedupe identically: email + last name,
  # first name against either the stored first_name or legal_first_name.
  def find_matching_person(values)
    first_name = values[:first_name].downcase
    Person
      .where("LOWER(last_name) = ? AND LOWER(email) = ?", values[:last_name].downcase, values[:email])
      .where("LOWER(first_name) = ? OR LOWER(COALESCE(legal_first_name, '')) = ?", first_name, first_name)
      .first
  end

  def resolve_registration(person, preview)
    existing = @event.event_registrations.find_by(registrant: person) unless person.new_record?

    if existing.nil?
      @result.registrations_created += 1
      preview.registration_status = :created
      return existing if @dry_run

      @event.event_registrations.create!(registrant: person, status: IMPORTED_STATUS)
    elsif existing.attended?
      @result.registrations_already_attended += 1
      preview.registration_status = :already_attended
      existing
    else
      @result.registrations_promoted += 1
      preview.registration_status = :promoted
      existing.update!(status: IMPORTED_STATUS) unless @dry_run
      existing
    end
  end

  def set_organization_preview(name, preview)
    if name.blank?
      preview.organization_status = :none
    elsif find_organization(name)
      @result.organizations_linked += 1
      preview.organization_status = :linked
    else
      @result.organizations_to_reconcile += 1
      preview.organization_status = :to_reconcile
    end
  end

  def set_payment_preview(values, preview)
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
    return preview.payment_status = :free if @event.cost_cents.to_i <= 0

    preview.payment_status = :will_record
    preview.payment_label = PAYMENT_TYPE_LABELS[payment_class.name]
    applied = [ cents, @event.cost_cents.to_i ].min
    @result.payments_recorded += 1
    @result.payments_amount_cents += applied

    discount = @event.cost_cents.to_i - applied
    return unless discount.positive?

    preview.discount_cents = discount
    @result.discounts_recorded += 1
    @result.discounts_amount_cents += discount
  end

  def persist_registration(person, registration, values)
    return if registration.nil?

    submission = import_submission(person, values)
    link_organization(person, registration, submission, values)
    apply_payment(person, registration, values)
  end

  def link_organization(person, registration, submission, values)
    organization = values[:organization].present? ? find_organization(values[:organization]) : nil
    return unless organization

    link = registration.event_registration_organizations.find_or_create_by!(organization: organization)
    # Only pin our submission on a link we created — an org a real registrant
    # already linked keeps its own pin.
    link.record_form_submission(submission) if link.previously_new_record?
    AffiliationServices::CreateFromRegistration.call(
      person: person,
      organization: organization,
      training_date: @event.start_date,
      facilitator_training: @event.facilitator_training,
      event_registration: registration
    )
  end

  # Applies the row's AmountPaid to the registration by finding-or-creating a
  # payment and then an allocation, capped at what the registration still owes —
  # so a re-run adds nothing and a fully-covered amount reads as "Paid".
  def apply_payment(person, registration, values)
    cents = parse_cents(values[:amount_paid])
    return if cents.nil? || cents <= 0

    payment_class = payment_class_for(values[:payment_type])
    return if payment_class.nil?
    return if payment_class == CheckPayment && values[:check_number].blank?

    to_allocate = [ cents, registration.remaining_cost ].min
    if to_allocate.positive?
      payment = resolve_payment(person, cents, payment_class, values[:check_number])
      registration.allocations.find_or_create_by!(source: payment) do |allocation|
        allocation.amount = to_allocate
      end
    end

    cover_remainder_with_discount(registration)
  end

  # Comps whatever the payment didn't cover — the gap between the event cost and
  # what was actually paid — so a partial amount still reads as "Paid". A re-run
  # sees nothing left to cover and adds no second discount.
  def cover_remainder_with_discount(registration)
    registration.allocations.reset
    remaining = registration.remaining_cost
    return unless remaining.positive?

    discount = Discount.new(amount_cents: remaining)
    discount.created_by = @import_user if discount.respond_to?(:created_by=)
    discount.updated_by = @import_user if discount.respond_to?(:updated_by=)
    discount.save!
    registration.allocations.create!(source: discount, amount: remaining)
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
  # re-saves) this one rather than piling up duplicates.
  def import_submission(person, values)
    submission = person.form_submissions
      .where(form: @registration_form, event: @event, role: "registration")
      .detect { |candidate| candidate.metadata&.key?(IMPORT_SOURCE_KEY) }
    submission ||= FormSubmission.create!(
      person: person, form: @registration_form, event: @event, role: "registration",
      metadata: { IMPORT_SOURCE_KEY => @source }
    )
    ANSWER_IDENTIFIERS.each do |identifier, key|
      value = values[key]
      field = form_field_for(identifier)
      next if value.blank? || field.nil?

      submission.persist_answer(field, value)
    end
    submission
  end

  def form_field_for(identifier)
    return @form_field_cache[identifier] if @form_field_cache.key?(identifier)

    @form_field_cache[identifier] =
      @registration_form.form_fields.find_by(field_identifier: identifier)
  end

  def find_organization(name)
    key = name.downcase
    return @organization_cache[key] if @organization_cache.key?(key)

    @organization_cache[key] = Organization.where("LOWER(name) = ?", key).first
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

    PAYMENT_TYPES[normalize_header(raw)]
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
