class Form < ApplicationRecord
  # Public-facing name for the "bulk payment" form — what visitors see on the
  # event page CTA and the form heading. Internal/admin labels still say "Bulk
  # payment" (the form role). Single source of truth so both ends stay in sync.
  BULK_PAYMENT_PUBLIC_NAME = "Pay for Other(s)".freeze

  # The collaboration agreement intake scenarios, each served by its own copy of
  # the form so submissions count per scenario and admins know which processing
  # (affiliation changes, portal access) a submission calls for. Keyed by the
  # stored `purpose` value, mapped to the admin-facing label.
  PURPOSES = {
    "on_demand" => "On-demand agreement",
    "reinstatement" => "Reinstatement agreement",
    "job_change" => "Job change agreement"
  }.freeze

  belongs_to :owner, polymorphic: true, optional: true
  has_many :form_fields, dependent: :destroy, inverse_of: :form
  has_many :event_forms, dependent: :destroy
  has_many :user_forms
  has_many :form_submissions
  has_many :reports, as: :owner
  # has_many through
  has_many :events, through: :event_forms

  # Nested attributes
  accepts_nested_attributes_for :form_fields, allow_destroy: true,
    reject_if: proc { |attrs| attrs["name"].blank? && attrs["id"].blank? }

  scope :standalone, -> { where(owner_id: nil, owner_type: nil) }
  scope :published, -> { where(published: true) }
  scope :not_event_connected, -> { where.missing(:event_forms) }
  scope :with_purpose, -> { where.not(purpose: nil) }

  before_validation :normalize_slug
  before_validation :normalize_purpose

  validates :purpose, inclusion: { in: PURPOSES.keys }, allow_nil: true
  validates :slug, uniqueness: true, allow_nil: true
  validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
    message: "may only contain lowercase letters, numbers, and hyphens" }, allow_blank: true
  validate :published_form_has_slug
  validate :event_form_not_published

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

  def purpose_label
    PURPOSES[purpose]
  end

  private

  # Blank stays nil (never ""), so the unique index tolerates the many forms with
  # none. Input that parameterizes away to nothing ("!!!") is left intact for the
  # format validation to reject rather than silently blanked.
  def normalize_slug
    return if slug.nil?

    self.slug = slug.parameterize.presence || slug.presence
  end

  # Blank select submissions stay nil so unpurposed forms don't trip the
  # inclusion validation.
  def normalize_purpose
    self.purpose = purpose.presence
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
