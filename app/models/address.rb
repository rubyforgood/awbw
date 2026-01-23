class Address < ApplicationRecord
  LOCALITIES = [ "LA City", "LA County", "Southern CA", "Northern CA",
                "Central CA", "Orange County", "Outside CA", "Outside USA", "Unknown" ]
  CONTACT_TYPES = [ nil, "work", "personal" ].freeze

  belongs_to :addressable, polymorphic: true

  validates :locality, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :address_type, inclusion: { in: CONTACT_TYPES }

  scope :active, -> { where(inactive: false) }

  def name
    "#{street_address}, #{city}, #{state} #{zip_code}"
  end
end
