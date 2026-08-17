class Form < ApplicationRecord
  # Public-facing name for the "bulk payment" form — what visitors see on the
  # event page CTA and the form heading. Internal/admin labels still say "Bulk
  # payment" (the form role). Single source of truth so both ends stay in sync.
  BULK_PAYMENT_PUBLIC_NAME = "Pay for Other(s)".freeze

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

  before_validation :normalize_slug

  validates :slug, uniqueness: true, allow_nil: true
  validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
    message: "may only contain lowercase letters, numbers, and hyphens" }, allow_blank: true
  validate :published_form_has_slug

  def display_name
    name.presence || (owner ? "#{owner.try(:name)} Form" : "New Form")
  end

  def standalone?
    owner_id.nil? && owner_type.nil?
  end

  # True when the form can be filled out at its public pretty URL: a standalone,
  # published form with a slug. The public controller and policy both gate on this.
  def publicly_fillable?
    standalone? && published? && slug.present?
  end

  private

  # Store the slug in URL-safe form so an admin can type "Volunteer Interest" and
  # get "volunteer-interest". A blank slug stays nil (not "") so the uniqueness
  # index tolerates the many forms that have none.
  def normalize_slug
    self.slug = slug.presence&.parameterize
  end

  def published_form_has_slug
    return unless published? && slug.blank?

    errors.add(:slug, "is required to publish a form")
  end
end
