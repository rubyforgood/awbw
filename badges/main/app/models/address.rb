class Address < ApplicationRecord
  LOCALITIES = [ "LA City", "LA County", "Southern CA", "Northern CA",
                "Central CA", "Orange County", "Outside CA", "Outside USA", "Unknown" ]
  CONTACT_TYPES = [ nil, "work", "personal", "mailing", "unknown" ].freeze
  # USPS abbreviations for the 50 states, DC, and the US territories the atlas
  # draws — the whitelist behind every "States" breakdown, so international
  # regions (e.g. "ON", "England") are excluded (they belong to the Countries map).
  US_STATE_ABBREVIATIONS = %w[
    AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO
    MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY
    PR GU VI AS MP
  ].freeze

  belongs_to :addressable, polymorphic: true, touch: true
  # Affiliations that point to this address as their organization address. Nullify
  # the link rather than block deletion when an org address is removed.
  has_many :affiliations, foreign_key: :organization_address_id, dependent: :nullify, inverse_of: :organization_address

  validates :locality, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :address_type, inclusion: { in: CONTACT_TYPES }

  scope :active, -> { where(inactive: false) }

  def name
    "#{street_address}, #{city}, #{state} #{zip_code}"
  end
end
