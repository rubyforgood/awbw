class FormSubmission < ApplicationRecord
  # Optional so a public form whose name/email questions are not required can
  # record an anonymous submission with no identity (see PublicFormSubmission).
  belongs_to :person, optional: true
  belongs_to :form
  belongs_to :event, optional: true
  has_many :form_answers, dependent: :destroy
  has_one :payment
  # A submission is a quote source: answers to a "quote" smart field are captured
  # as Quotes linked here, so they carry a source and show under the quotes Source
  # filter like workshop/report quotes. Nullify (not destroy) so a captured quote
  # outlives the submission — matching how reports and workshop logs keep theirs.
  has_many :quotable_item_quotes, as: :quotable, dependent: :nullify, inverse_of: :quotable
  has_many :quotes, through: :quotable_item_quotes

  accepts_nested_attributes_for :form_answers

  # Raised when a file-upload answer's value isn't a usable upload (tampered/stale
  # signed id); callers rescue it into a form error rather than a 500.
  UnreadableUpload = Class.new(StandardError)

  UNREADABLE_UPLOAD_MESSAGE = "We couldn't read one of your uploaded files. Please choose it again.".freeze

  # The index's "Organization linking" filter vocabulary, keyed on whether an org
  # is linked directly to the submission (see DIRECT_ORG_LINK_SQL):
  #   pending  — gave an org answer, not linked yet (the actionable queue).
  #   linked   — an org was linked (processed).
  #   unlinked — not linked, either kind: pending or no-org-answer.
  #   none     — no organization answer was provided.
  ORG_LINK_STATUS_FILTER_OPTIONS = [
    [ "Linked", "linked" ],
    [ "Unlinked", "unlinked" ],
    [ "Pending", "pending" ],
    [ "No org provided", "none" ]
  ].freeze

  scope :bulk_payment, -> { where(role: "bulk_payment") }

  # The bulk payments index "Payment status" filter vocabulary, keyed on the
  # submission's payment (see the payment badge):
  #   unpaid               — no payment recorded yet ("No payment yet").
  #   partially_allocated  — a payment exists with some amount unallocated.
  #   fully_allocated      — a payment exists with everything allocated.
  PAYMENT_STATUS_FILTER_OPTIONS = [
    [ "No payment yet", "unpaid" ],
    [ "Not fully allocated", "partially_allocated" ],
    [ "Fully allocated", "fully_allocated" ]
  ].freeze

  scope :payment_status, ->(value) {
    case value
    when "unpaid" then where.missing(:payment)
    when "partially_allocated" then joins(:payment).where("payments.amount_cents_remaining > 0")
    when "fully_allocated" then joins(:payment).where(payments: { amount_cents_remaining: 0 })
    else all
    end
  }

  # Submitted on `created_at` — there is no separate submitted_at column.
  scope :submitted_between, ->(start_date, end_date) {
    scope = all
    scope = scope.where(created_at: start_date.beginning_of_day..) if start_date
    scope = scope.where(created_at: ..end_date.end_of_day) if end_date
    scope
  }

  # Submissions this organization is directly linked to, by either link
  # (ADR-0002 D5). A matching affiliation the person happens to hold is not a
  # link and does not make the submission match.
  scope :for_organization, ->(organization_id) {
    id = organization_id.to_i
    where(
      "JSON_CONTAINS(JSON_EXTRACT(form_submissions.metadata, '$.linked_organization_ids'), CAST(? AS JSON)) " \
      "OR EXISTS (#{PINNED_ORG_LINK_SQL} AND event_registration_organizations.organization_id = ?)",
      id, id
    )
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

  # The registration-org row a submission is pinned to — the link public
  # registration records (EventRegistrationOrganization#form_submission_id)
  # instead of writing metadata. Fragment, so callers can add their own AND.
  PINNED_ORG_LINK_SQL = "SELECT 1 FROM event_registration_organizations " \
    "WHERE event_registration_organizations.form_submission_id = form_submissions.id".freeze

  # SQL test for either direct link (ADR-0002 D5): the explicit one an admin
  # records in metadata, or the registration-org row this submission is pinned
  # to. COALESCE: metadata (or the key) may be absent.
  DIRECT_ORG_LINK_SQL = "(COALESCE(JSON_LENGTH(JSON_EXTRACT(form_submissions.metadata, " \
    "'$.linked_organization_ids')), 0) > 0 OR EXISTS (#{PINNED_ORG_LINK_SQL}))".freeze

  # Linking status keyed on whether an org is *directly linked to the submission*
  # — a matching affiliation the person happens to hold does NOT count. Same
  # vocabulary and the same join-backed answer as the registrants roster
  # (EventRegistration.organization_linking_status):
  #   linked   — an org was linked (processed).
  #   unlinked — no org linked, whichever kind: pending or no org answer (broad).
  #   pending  — gave an org answer but nothing linked yet — the actionable queue.
  #   none     — no organization answer was provided.
  scope :org_link_status, ->(value) {
    answered = org_name_answers.select(:form_submission_id)
    case value
    when "linked" then where(DIRECT_ORG_LINK_SQL)
    when "unlinked" then where.not(DIRECT_ORG_LINK_SQL)
    when "pending" then where(id: answered).where.not(DIRECT_ORG_LINK_SQL)
    when "none" then where.not(id: answered).where.not(DIRECT_ORG_LINK_SQL)
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
    form_ids = Array(params[:form_id]).reject(&:blank?)
    results = results.where(form_id: form_ids) if form_ids.any?
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

  def anonymous?
    person_id.nil?
  end

  # The event this submission belongs to: the directly stored one, or — for
  # submissions created before event_id existed — resolved through the form's
  # matching join role.
  def resolved_event
    event || form.events.find_by(event_forms: { role: role })
  end

  # Answers keyed by their field's identifier. Bulk payment (and similar) forms
  # address fields by identifier rather than position. Reuses an already-loaded
  # association so per-row calls on a preloaded index don't requery. Each answer
  # is also indexed under its canonical identifier, so a consumer keying on the
  # canonical name (e.g. "organization_name") finds an answer stored under a
  # legacy spelling (e.g. "payer_organization") without every call site knowing
  # both.
  def answers_by_identifier
    answers = form_answers.loaded? ? form_answers : form_answers.includes(:form_field)
    answers.each_with_object({}) do |answer, map|
      identifier = answer.form_field&.field_identifier
      next if identifier.blank?

      map[identifier] = answer.submitted_answer
      canonical = FormField.canonical_identifier(identifier)
      map[canonical] = answer.submitted_answer unless canonical == identifier
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
  # linked (ADR-0002 D5).

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

  # --- Provenance: how the submission was collected ---
  # A callout submission carries the form's own role (so it aggregates with any
  # other submission of that form), so this metadata flag — not the role — is what
  # records that the registrant filled it out inline on a ticket callout.

  def collected_via
    (metadata || {})["collected_via"]
  end

  def collected_via_callout?
    collected_via == "callout"
  end

  def record_callout_collection!(callout)
    update!(metadata: (metadata || {}).merge("collected_via" => "callout", "collected_via_callout_id" => callout.id))
  end

  # A quotable's display label + link target: the quotes show page renders each
  # source via `quotable.title` and `polymorphic_path(quotable)`.
  def title
    "#{form&.display_name} submission ##{id}"
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
