# frozen_string_literal: true

class WorkshopAgeRange < ApplicationRecord
  attr_accessor :_create

  belongs_to :workshop
  belongs_to :age_range

  validates :workshop_id, :age_range_id, presence: true
  validates :workshop_id, uniqueness: { scope: :age_range_id }
end
