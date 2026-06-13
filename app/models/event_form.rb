class EventForm < ApplicationRecord
  belongs_to :event
  belongs_to :form

  ROLES = %w[registration scholarship bulk_payment ce_credit general].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :form_id, uniqueness: { scope: [ :event_id, :role ] }

  ROLES.each do |role_name|
    scope role_name, -> { where(role: role_name) }
  end
end
