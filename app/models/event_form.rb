class EventForm < ApplicationRecord
  belongs_to :event
  belongs_to :form

  ROLES = %w[registration scholarship bulk_payment continuing_education].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :form_id, uniqueness: { scope: [ :event_id, :role ] }

  scope :registration, -> { where(role: "registration") }
  scope :scholarship, -> { where(role: "scholarship") }
  scope :bulk_payment, -> { where(role: "bulk_payment") }
  scope :continuing_education, -> { where(role: "continuing_education") }

  after_create :unpublish_public_form

  private

  # An event-connected form is never offered at a public link, so linking a
  # published standalone form to an event retires its public form.
  def unpublish_public_form
    form.update_column(:published, false) if form.published?
  end
end
