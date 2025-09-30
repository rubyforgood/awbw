class WorkshopVariation < ApplicationRecord
  belongs_to :workshop

  scope :active, -> { where(inactive: false) }

end
