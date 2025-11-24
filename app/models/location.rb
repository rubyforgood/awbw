class Location < ApplicationRecord # TODO remove this class if unused
  # Validations
  validates_presence_of :city, :country

  def name
    "#{city}, #{state}"
  end
end
