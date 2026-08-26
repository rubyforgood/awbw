require "csv"

# Bulk-imports event registrants into one existing event from an uploaded
# CSV whose columns are FirstName, LastName,
# Organization, EMail. Every row is treated as someone who ATTENDED, so it
# simulates the registration a real submission would create and then lets the
# same reconciliation flow take over:
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
#
# No emails are sent, no mailing-list subscription, tags, addresses, or CE are
# created — the sheet carries none of that, and this is a historical backfill.
# Runs in a transaction with a dry_run mode that rolls back for the preview.
class EventRegistrationImporter
  IMPORTED_STATUS = "attended".freeze

  # Registration-form field_identifier → the row field whose value we mirror into
  # a FormAnswer, so the simulated submission reads back like a real one.
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

  # Header label (lowercased, whitespace-collapsed) → the field we read from the
  # row, tolerant of the common spellings staff export.
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
    "email address" => :email
  }.freeze

  SUPPORTED_EXTENSIONS = %w[csv].freeze

  # An event can be imported into only when it has a registration form carrying an
  # organization-name field — without it the typed org has nowhere to live and the
  # reconciliation queue would never see it.
  def self.importable?(event)
    form = event.registration_form
    return false unless form

    form.form_fields.exists?(field_identifier: FormField.aliased_identifiers(ORGANIZATION_NAME_IDENTIFIER))
  end

  Result = Struct.new(
    :rows_processed, :people_created, :people_matched,
    :registrations_created, :registrations_promoted, :registrations_already_attended,
    :organizations_linked, :organizations_to_reconcile,
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
        "skipped: #{skipped.size}"
      ].join("\n")
    end
  end

  # A row-level summary for the preview interstitial: what the row would create,
  # match, or skip. person_status/registration_status/organization_status are the
  # symbols the preview view renders as badges.
  RowPreview = Struct.new(
    :number, :first_name, :last_name, :email, :organization_name,
    :person_status, :person_label,
    :registration_status, :organization_status,
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
      organization: clean(row[:organization])
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

    persist_registration(person, registration, values) unless @dry_run

    @result.rows << preview
  end

  def missing_required(values)
    [
      [ "first name", values[:first_name] ], [ "last name", values[:last_name] ], [ "email", values[:email] ]
    ].select { |_label, value| value.blank? }.map(&:first)
  end

  # Mirrors PublicRegistration#find_matching_person: email + last name, accepting
  # the typed first name against either the stored first_name or legal_first_name.
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

  # Leave the import's own registration submission, then link a matched org (with
  # its facilitator affiliation). An existing org link (a real registrant already
  # linked it) keeps its own submission pin — we only pin one we just created.
  def persist_registration(person, registration, values)
    return if registration.nil?

    submission = import_submission(person, values)
    organization = values[:organization].present? ? find_organization(values[:organization]) : nil
    return unless organization

    link = registration.event_registration_organizations.find_or_create_by!(organization: organization)
    link.record_form_submission(submission) if link.previously_new_record?
    AffiliationServices::CreateFromRegistration.call(
      person: person,
      organization: organization,
      training_date: @event.start_date,
      facilitator_training: @event.facilitator_training,
      event_registration: registration
    )
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
      @registration_form.form_fields.find_by(field_identifier: FormField.aliased_identifiers(identifier))
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
end
