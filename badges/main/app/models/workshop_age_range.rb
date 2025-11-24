class WorkshopAgeRange < ApplicationRecord
  attr_accessor :_create

  belongs_to :workshop
  belongs_to :age_range

  # Validations
  validates_presence_of :workshop_id, :age_range_id
  validates_uniqueness_of :workshop_id, scope: :age_range_id
end
