class WorkshopVariation < ApplicationRecord
  belongs_to :workshop
  belongs_to :created_by, class_name: 'User', optional: true

  scope :active, -> { where(inactive: false) }

  validates :name, presence: true, uniqueness: { scope: :workshop_id, case_sensitive: false }
end
