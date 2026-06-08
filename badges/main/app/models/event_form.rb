class EventForm < ApplicationRecord
  belongs_to :event
  belongs_to :form

  ROLES = %w[registration scholarship group_payment].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :form_id, uniqueness: { scope: [ :event_id, :role ] }

  scope :registration, -> { where(role: "registration") }
  scope :scholarship, -> { where(role: "scholarship") }
  scope :group_payment, -> { where(role: "group_payment") }
end
