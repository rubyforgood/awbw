class FormSubmission < ApplicationRecord
  belongs_to :person
  belongs_to :form
  belongs_to :event, optional: true
  has_many :form_answers, dependent: :destroy
  has_one :payment

  accepts_nested_attributes_for :form_answers

  # Raised when a file-upload answer's value isn't a usable upload (tampered/stale
  # signed id); callers rescue it into a form error rather than a 500.
  UnreadableUpload = Class.new(StandardError)

  UNREADABLE_UPLOAD_MESSAGE = "We couldn't read one of your uploaded files. Please choose it again.".freeze

  # The index's "Organization linking" filter vocabulary: linked = the submitted
  # organization name matches one of the person's active affiliations.
  # Mirrors the registrants roster (events/_registrant_filters): "pending" is the
  # actionable queue (named an org, not linked), "unlinked" is the broad set (not
  # linked, whichever — including no org answer), "linked" is processed.
  ORG_LINK_STATUS_FILTER_OPTIONS = [
    [ "Pending", "pending" ],
    [ "Linked", "linked" ],
    [ "Unlinked", "unlinked" ]
  ].freeze

  scope :bulk_payment, -> { where(role: "bulk_payment") }

  # Submitted on `created_at` — there is no separate submitted_at column.
  scope :submitted_between, ->(start_date, end_date) {
    scope = all
    scope = scope.where(created_at: start_date.beginning_of_day..) if start_date
    scope = scope.where(created_at: ..end_date.end_of_day) if end_date
    scope
  }

  # Submissions associated with an organization, reconciling every signal:
  #   1. directly — an explicit link recorded in metadata (see #link_organization!),
  #   2. via the submission's event registration — the join row pinned to this
  #      submission, or a registration for the same person + event linked to the org.
  scope :for_organization, ->(organization_id) {
    oid = organization_id.to_i
    direct = where(
      "JSON_CONTAINS(JSON_EXTRACT(form_submissions.metadata, '$.linked_organization_ids'), CAST(? AS JSON))", oid
    )
    pinned = EventRegistrationOrganization.where(organization_id: oid).select(:form_submission_id)
    via_registration = joins(
      "INNER JOIN event_registrations " \
      "ON event_registrations.registrant_id = form_submissions.person_id " \
      "AND event_registrations.event_id = form_submissions.event_id"
    ).joins(
      "INNER JOIN event_registration_organizations " \
      "ON event_registration_organizations.event_registration_id = event_registrations.id"
    ).where(event_registration_organizations: { organization_id: oid }).select(:id)

    direct.or(where(id: pinned)).or(where(id: via_registration))
  }

  scope :search, ->(query) {
    joins(:person).where(
      "CONCAT_WS(' ', people.first_name, people.last_name) LIKE :q OR people.email LIKE :q OR people.email_2 LIKE :q",
      q: "%#{sanitize_sql_like(query)}%"
    )
  }

  # Answers stored against an organization-name field (canonical or legacy
  # "agency_name"), the submitted-organization signal the index filters on.
  def self.org_name_answers
    FormAnswer.joins(:form_field)
      .where(form_fields: { field_identifier: FormField.aliased_identifiers("organization_name") })
      .where.not(submitted_answer: [ nil, "" ])
  end

  # SQL test for an explicit admin link recorded in metadata (see
  # #link_organization!). COALESCE: metadata (or the key) may be absent.
  EXPLICIT_ORG_LINK_SQL = "COALESCE(JSON_LENGTH(JSON_EXTRACT(form_submissions.metadata, '$.linked_organization_ids')), 0) > 0".freeze

  # Linking status keyed on whether an org is *directly linked to the submission*
  # (the metadata link an admin sets in the editor) — a matching affiliation the
  # person happens to hold does NOT count. Mirrors the registrants roster:
  #   linked   — an org was linked (processed).
  #   unlinked — no org linked, whichever kind (broad; includes no org answer).
  #   pending  — named an org but nothing linked yet — the actionable queue.
  scope :org_link_status, ->(value) {
    answered = org_name_answers.select(:form_submission_id)
    case value
    when "linked" then where(EXPLICIT_ORG_LINK_SQL)
    when "unlinked" then where.not(EXPLICIT_ORG_LINK_SQL)
    when "pending" then where(id: answered).where.not(EXPLICIT_ORG_LINK_SQL)
    else all
    end
  }

  # Mirrors EventRegistration.account_status (same filter vocabulary as the
  # registrants roster), keyed on the submission's person.
  scope :account_status, ->(value) {
    with_user = User.where.not(person_id: nil).select(:person_id)
    has_access = User.has_access.where.not(person_id: nil).select(:person_id)
    invited = User.where.not(person_id: nil).where.not(welcome_instructions_sent_at: nil).select(:person_id)
    case value
    when "none" then where.not(person_id: with_user)
    when "has_access" then where(person_id: has_access)
    when "invited" then where(person_id: invited).where.not(person_id: has_access)
    when "no_access" then where(person_id: with_user).where.not(person_id: has_access).where.not(person_id: invited)
    when "not_invited" then where.not(person_id: invited).where.not(person_id: has_access)
    else all
    end
  }

  # The submission-side agreement scenarios (ADR-0002), keyed by scenario name
  # with the admin-facing label for the panel chip and index filter.
  LINKING_SCENARIOS = {
    "on_demand" => "On-demand agreement",
    "new_job" => "New job agreement",
    "reinstatement" => "Reinstatement agreement"
  }.freeze

  # Agreement-scenario submissions — a specific scenario, or "any" for all
  # three at once. On-demand is a standalone public submission to a
  # registration-role form; new_job/reinstatement are form roles.
  scope :scenario, ->(value) {
    scoped = joins(:form)
    on_demand = scoped.where(role: "public", forms: { role: "registration" })
    case value
    when "on_demand" then on_demand
    when "new_job", "reinstatement" then scoped.where(forms: { role: value })
    when "any" then scoped.where(forms: { role: %w[new_job reinstatement] }).or(on_demand)
    else all
    end
  }

  validates :slug, uniqueness: true, allow_nil: true

  # Bulk payment submissions are reachable by their payer (who has no account)
  # through a public, slug-based ticket URL. Other roles are reached by id.
  before_create :generate_slug, if: :bulk_payment?

  # Narrow the admin index by the optional filter params. Each filter is a no-op
  # when its param is blank, so combinations stack.
  def self.search_by_params(params)
    results = all
    results = results.where(person_id: params[:person_id]) if params[:person_id].present?
    results = results.where(form_id: params[:form_id]) if params[:form_id].present?
    results = results.where(event_id: params[:event_id]) if params[:event_id].present?
    results = results.where(role: params[:role]) if params[:role].present?
    results = results.for_organization(params[:organization_id]) if params[:organization_id].present?
    results = results.search(params[:search]) if params[:search].present?
    results = results.org_link_status(params[:org_status]) if params[:org_status].present?
    results = results.account_status(params[:account_status]) if params[:account_status].present?
    results = results.scenario(params[:scenario]) if params[:scenario].present?
    results.submitted_between(parse_date(params[:start_date]), parse_date(params[:end_date]))
  end

  def self.parse_date(value)
    return if value.blank?
    Date.parse(value)
  rescue ArgumentError, TypeError
    nil
  end

  def self.generate_unique_slug
    loop do
      slug = SecureRandom.urlsafe_base64(16)
      break slug unless exists?(slug: slug)
    end
  end

  # Persist one field's answer onto this submission. File-upload fields attach
  # their blob to the answer's Asset (hardened against forged/stale/oversized
  # uploads); everything else stores the (comma-joined) text. Shared by every
  # submission flow — event registration, public forms, and bulk payment.
  def persist_answer(field, raw_value)
    record = form_answers.find_or_initialize_by(form_field: field)
    record.question_name_when_answered = field.name

    if field.file_upload?
      attach_uploaded_file(record, raw_value)
    else
      record.update!(submitted_answer: answer_text(raw_value))
    end
  end

  def bulk_payment?
    role == "bulk_payment"
  end

  # The event this submission belongs to: the directly stored one, or — for
  # submissions created before event_id existed — resolved through the form's
  # matching join role.
  def resolved_event
    event || form.events.find_by(event_forms: { role: role })
  end

  # Answers keyed by their field's identifier. Bulk payment (and similar) forms
  # address fields by identifier rather than position. Reuses an already-loaded
  # association so per-row calls on a preloaded index don't requery.
  def answers_by_identifier
    answers = form_answers.loaded? ? form_answers : form_answers.includes(:form_field)
    answers.each_with_object({}) do |answer, map|
      identifier = answer.form_field&.field_identifier
      map[identifier] = answer.submitted_answer if identifier.present?
    end
  end

  # Attendees captured by the bulk payment form, stored as a JSON array under the
  # "bulk_payment_attendees" field.
  def bulk_payment_attendees
    raw = answers_by_identifier["bulk_payment_attendees"]
    return [] if raw.blank?

    parsed = JSON.parse(raw)
    parsed.is_a?(Array) ? parsed : []
  rescue JSON::ParserError
    []
  end

  # Number of attendees the payer submitted, falling back to the size of the
  # attendees list when an explicit count is absent.
  def bulk_payment_attendee_count
    count = answers_by_identifier["number_of_attendees"].to_i
    count.positive? ? count : bulk_payment_attendees.size
  end

  # Expected total for the submission (event cost times attendee count), so the
  # amount can be shown even before a payment record lands.
  def bulk_payment_amount_cents(event)
    event.cost_cents.to_i * bulk_payment_attendee_count
  end

  # Which linking scenario this submission drives (ADR-0002): its form's role,
  # with a standalone public submission to a registration-role form being the
  # on-demand agreement. Nil for everything else — no agreement processing.
  def linking_scenario
    case form.role
    when "new_job", "reinstatement" then form.role
    when "registration" then "on_demand" if role == "public"
    end
  end

  def agreement_scenario?
    linking_scenario.present?
  end

  # --- Linked organizations (explicit admin resolution) ---
  # Recorded when an admin links an org to this submission — from the
  # submission's own org-linking editor, or back-applied by the event
  # registration editor when this submission's answers describe the org. Keeps
  # a submitted name that was resolved to a differently-named org reading as
  # linked, where the affiliation-name match alone would not.

  def linked_organization_ids
    (metadata || {}).fetch("linked_organization_ids", [])
  end

  def link_organization!(organization_id)
    ids = linked_organization_ids | [ organization_id.to_i ]
    update!(metadata: (metadata || {}).merge("linked_organization_ids" => ids))
  end

  def linked_organizations
    Organization.where(id: linked_organization_ids)
  end

  # Affiliations the agreement scenario end-dated when an admin linked the
  # submitted organization — flagged on the processing panel so a wrongly-ended
  # one (e.g. a multi-org facilitator changing only one job) can be corrected.

  def scenario_ended_affiliation_ids
    (metadata || {}).fetch("scenario_ended_affiliation_ids", [])
  end

  def record_scenario_ended!(affiliation_ids)
    return if affiliation_ids.empty?

    ids = scenario_ended_affiliation_ids | affiliation_ids.map(&:to_i)
    update!(metadata: (metadata || {}).merge("scenario_ended_affiliation_ids" => ids))
  end

  # --- Linked registrations (bulk payment designations) ---

  def linked_registration_ids
    (metadata || {}).fetch("linked_registration_ids", [])
  end

  def link_registration!(event_registration_id)
    ids = linked_registration_ids | [ event_registration_id.to_i ]
    update!(metadata: (metadata || {}).merge("linked_registration_ids" => ids))
  end

  def unlink_registration!(event_registration_id)
    ids = linked_registration_ids - [ event_registration_id.to_i ]
    update!(metadata: (metadata || {}).merge("linked_registration_ids" => ids))
  end

  def linked_registrations
    EventRegistration.where(id: linked_registration_ids)
  end

  private

  def answer_text(raw_value)
    raw_value.is_a?(Array) ? raw_value.reject(&:blank?).join(", ") : raw_value.to_s
  end

  def attach_uploaded_file(record, raw_value)
    # An untouched file input posts blank — keep the file the answer already has.
    record.sync_uploaded_filename!
    return if raw_value.blank?

    # Named type: assets.type defaults to PrimaryAsset (images only), which would
    # reject the document types this field offers.
    asset = record.asset || record.build_asset(type: FormUploadAsset.name)
    asset.file.attach(upload_attachable(raw_value))
    asset.save!
    record.sync_uploaded_filename!
  end

  # Resolve a direct-upload signed id leniently: find_signed! would raise (and 500
  # a public endpoint) on a forged/stale id, so turn a miss into a form error. A
  # multipart UploadedFile (no direct-upload JS) attaches as-is.
  def upload_attachable(raw_value)
    return raw_value unless raw_value.is_a?(String)

    ActiveStorage::Blob.find_signed(raw_value) || raise(UnreadableUpload, UNREADABLE_UPLOAD_MESSAGE)
  end

  def generate_slug
    self.slug ||= self.class.generate_unique_slug
  end
end
