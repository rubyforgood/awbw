class Form < ApplicationRecord
  # Public-facing name for the "bulk payment" form — what visitors see on the
  # event page CTA and the form heading. Internal/admin labels still say "Bulk
  # payment" (the form role). Single source of truth so both ends stay in sync.
  BULK_PAYMENT_PUBLIC_NAME = "Pay for Participant(s)".freeze

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

  def display_name
    name.presence || (owner ? "#{owner.try(:name)} Form" : "New Form")
  end
end
