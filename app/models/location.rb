# frozen_string_literal: true

class Location < ApplicationRecord
  # Validations
  validates :city, :country, presence: true

  # Methods
  def name
    "#{city}, #{state}"
  end
end
