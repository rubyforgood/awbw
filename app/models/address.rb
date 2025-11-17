class Address < ApplicationRecord
  belongs_to :addressable, polymorphic: true

  validates :locality, presence: true
  validates :city, presence: true
  validates :state, presence: true

  scope :active, -> { where(inactive: false) }

  def name
    "#{street}, #{city}, #{state} #{zip}"
  end

  def city_state
    "#{city}, #{state}"
  end
end
