class Form < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # Public-facing name for the "bulk payment" form — what visitors see on the
  # event page CTA and the form heading. Internal/admin labels still say "Bulk
  # payment" (the form role). Single source of truth so both ends stay in sync.
  BULK_PAYMENT_PUBLIC_NAME = "Pay for Other(s)".freeze

  NAME_MAX_LENGTH = 255

  # Form roles whose standalone public submissions are agreement intake
  # scenarios with affiliation processing (ADR-0002): a standalone
  # registration-role form is the on-demand agreement (the registration flow,
  # timestamped at submission), new_job / reinstatement carry their own
  # reconciliation rules, and close_program end-dates the person's affiliations
  # at the named organization (deactivation, the mirror of the others). Drives
  # the person-page "send link" panel and the submissions index scenario filter.
  AGREEMENT_ROLES = %w[registration new_job reinstatement close_program].freeze

  ROLE_OPTIONS = [
    [ "General", "general" ],
    [ "Registration", "registration" ],
    [ "New job", "new_job" ],
    [ "Reinstatement", "reinstatement" ],
    [ "Scholarship", "scholarship" ],
    [ "Bulk Payment", "bulk_payment" ],
    [ "Continuing Education", "continuing_education" ],
    [ "Close program", "close_program" ],
    [ "Day 1 survey", "day_1_survey" ],
    [ "Day 2 survey", "day_2_survey" ],
    [ "Post-event survey", "post_event_survey" ],
    [ "Post-training recipients survey", "recipient_survey" ]
  ].freeze

  # Each survey role marks the one form the built-in callouts deliver for it.
  SURVEY_ROLES = ROLE_OPTIONS.map(&:last).select { |role| role.include?("survey") }.freeze
  SURVEY_HEADERS = { "recipient_survey" => "Scholarship survey" }.freeze

  # Roles whose submissions are processed against a Person, so they can't be anonymous.
  IDENTIFIED_ROLES = (AGREEMENT_ROLES + %w[scholarship bulk_payment continuing_education]).freeze

  # The questions that identify a public respondent (used to build their Person).
  IDENTITY_IDENTIFIERS = %w[first_name last_name primary_email].freeze
  # Optional on an anonymous form, however they're flagged.
  ANONYMOUS_OPTIONAL_IDENTIFIERS = (IDENTITY_IDENTIFIERS + %w[confirm_email]).freeze

  belongs_to :owner, polymorphic: true, optional: true
  has_many :form_fields, dependent: :destroy, inverse_of: :form
  has_many :event_forms, dependent: :destroy
  has_many :user_forms
  has_many :form_submissions
  has_many :form_completions, dependent: :destroy
  has_many :reports, as: :owner
  # has_many through
  has_many :events, through: :event_forms

  # Nested attributes
  accepts_nested_attributes_for :form_fields, allow_destroy: true,
    reject_if: proc { |attrs| attrs["name"].blank? && attrs["id"].blank? }

  scope :standalone, -> { where(owner_id: nil, owner_type: nil) }
  scope :owned, -> { standalone.invert_where }
  scope :published, -> { where(published: true) }
  scope :not_event_connected, -> { where.missing(:event_forms) }
  # The publicly fillable agreement forms — the ones the person-page panel
  # offers to send a link for.
  scope :agreement_forms, -> { standalone.published.not_event_connected.where(role: AGREEMENT_ROLES).where.not(slug: nil) }

  before_validation :normalize_slug

  validates :name, length: { maximum: NAME_MAX_LENGTH }
  validates :role, uniqueness: { message: "is already used by another form" }, if: :survey_role?
  validates :slug, uniqueness: true, allow_nil: true
  validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
    message: "may only contain lowercase letters, numbers, and hyphens" }, allow_blank: true
  validate :published_form_has_slug
  validate :anonymous_allowed_for_role
  validate :event_form_not_published

  def self.survey(role)
    standalone.find_by(role:)
  end

  def self.survey_header(role)
    SURVEY_HEADERS.fetch(role) { ROLE_OPTIONS.rassoc(role)&.first || role.to_s.humanize }
  end

  def survey_role?
    role.in?(SURVEY_ROLES)
  end

  def display_name
    name.presence || (owner ? "#{owner.try(:name)} Form" : "New Form")
  end

  def standalone?
    owner_id.nil? && owner_type.nil?
  end

  def event_connected?
    event_forms.exists?
  end

  # Gates the public /f/:slug endpoint (controller + FormPolicy#public_show?). An
  # event-connected form stays tied to its event and is never offered publicly.
  def publicly_fillable?
    standalone? && !event_connected? && published? && slug.present?
  end

  # A form not set to anonymous always requires the full name/email identity,
  # however its identity questions are flagged.
  def requires_identity?
    !anonymous?
  end

  def asks_identity?
    form_fields.any? { |field| field.field_identifier.in?(IDENTITY_IDENTIFIERS) }
  end

  # A form that requires identity but can't collect it rejects every public submission.
  def missing_identity_questions?
    requires_identity? && (IDENTITY_IDENTIFIERS - form_fields.map(&:field_identifier)).any?
  end

  # Whether submitted answers name the respondent: on an anonymous form only all
  # three of first name, last name, and email credit a person; anything less
  # (including a form that doesn't ask them) leaves the submission anonymous.
  def identified_by?(form_params)
    params = form_params.to_h.transform_keys(&:to_s)
    identity_fields = form_fields.select { |field| field.field_identifier.in?(IDENTITY_IDENTIFIERS) }.index_by(&:field_identifier)
    IDENTITY_IDENTIFIERS.all? do |identifier|
      field = identity_fields[identifier]
      field.present? && params[field.id.to_s].to_s.strip.present?
    end
  end

  # Whether a submission must carry an answer for this field: the field's own
  # required flag, plus the identity questions a registration form always needs.
  # An anonymous form never requires the name and email questions.
  def requires_answer?(field)
    return false if anonymous? && field.field_identifier.in?(ANONYMOUS_OPTIONAL_IDENTIFIERS)

    field.required? || (requires_identity? && field.field_identifier.in?(IDENTITY_IDENTIFIERS))
  end

  private

  # Blank stays nil (never ""), so the unique index tolerates the many forms with
  # none. Input that parameterizes away to nothing ("!!!") is left intact for the
  # format validation to reject rather than silently blanked.
  def normalize_slug
    return if slug.nil?

    self.slug = slug.parameterize.presence || slug.presence
  end

  def anonymous_allowed_for_role
    return unless anonymous? && role.in?(IDENTIFIED_ROLES)

    errors.add(:anonymous, "can't be turned on for a #{Form.survey_header(role).downcase} form, which is processed against a person")
  end

  def published_form_has_slug
    return unless published? && slug.blank?

    errors.add(:slug, "is required to publish a form")
  end

  def event_form_not_published
    return unless published? && event_connected?

    errors.add(:published, "can't be enabled for a form connected to an event")
  end
end
