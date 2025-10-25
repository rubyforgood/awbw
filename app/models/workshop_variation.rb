class WorkshopVariation < ApplicationRecord
  belongs_to :workshop

  scope :active, -> { where(inactive: false) }

  validates :name, presence: true, uniqueness: { scope: :workshop_id, case_sensitive: false }
end
