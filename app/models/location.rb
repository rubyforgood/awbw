class Location < ApplicationRecord
  # Validations
  validates_presence_of :city, :country

  # Methods
  def name
    "#{city}, #{state}"
  end
end
