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
  ORG_LINK_STATUS_FILTER_OPTIONS = [
    [ "Linked", "linked" ],
    [ "Not linked", "unlinked" ],
    [ "No organization answer", "none" ]
  ].freeze

  scope :bulk_payment, -> { where(role: "bulk_payment") }

  # Submitted on `created_at` — there is no separate submitted_at column.
  scope :submitted_between, ->(start_date, end_date) {
    scope = all
    scope = scope.where(created_at: start_date.beginning_of_day..) if start_date
    scope = scope.where(created_at: ..end_date.end_of_day) if end_date
    scope
  }

  # Submissions linked to an organization through an event registration. This is
  # the only queryable submission → organization path (the org an answer names is
  # otherwise just free text); submissions that never linked an org won't match.
  scope :for_organization, ->(organization_id) {
    where(id: EventRegistrationOrganization.where(organization_id: organization_id).select(:form_submission_id))
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

  scope :org_link_status, ->(value) {
    answered = org_name_answers.select(:form_submission_id)
    case value
    when "linked", "unlinked"
      # Linked: the submitted name matches an org the person holds an active (or
      # pending) affiliation with — the same rule as the index's Linked chip.
      linked = org_name_answers
        .joins(form_submission: { person: { affiliations: :organization } })
        .merge(Affiliation.active_or_pending)
        .where("organizations.name = form_answers.submitted_answer")
        .select(:form_submission_id)
      value == "linked" ? where(id: linked) : where(id: answered).where.not(id: linked)
    when "none" then where.not(id: answered)
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

  # Purposed (agreement scenario) submissions — a specific scenario, or "any"
  # for all three at once (see Form::PURPOSES).
  scope :scenario, ->(value) {
    value == "any" ? joins(:form).merge(Form.with_purpose) : joins(:form).where(forms: { purpose: value })
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
