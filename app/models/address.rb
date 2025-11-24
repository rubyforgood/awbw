class Address < ApplicationRecord
  LOCALITIES = ["LA City", "LA County", "Southern CA", "Northern CA",
                "Central CA", "Orange County", "Outside CA", "Outside USA"]

  belongs_to :addressable, polymorphic: true

  validates :locality, presence: true
  validates :city, presence: true
  validates :state, presence: true

  scope :active, -> { where(inactive: false) }

  def name
    "#{street}, #{city}, #{state} #{zip}"
  end
end
