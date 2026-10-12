class Address < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  LOCALITIES = [ "LA City", "LA County", "Southern CA", "Northern CA",
                "Central CA", "Orange County", "Outside CA", "Outside USA", "Unknown" ]
  UNKNOWN_CONTACT_TYPE = "unknown"
  CONTACT_TYPES = [ nil, "work", "personal", "mailing", UNKNOWN_CONTACT_TYPE ].freeze
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

  before_validation :type_as_unknown

  validates :locality, presence: true
  validates :city, presence: true, length: { maximum: 255 }
  validates :state, presence: true
  validates :address_type, inclusion: { in: CONTACT_TYPES }
  validates :street_address, length: { maximum: 255 }
  validates :zip_code, length: { maximum: 255 }
  validates :district, length: { maximum: 255 }
  validates :county, length: { maximum: 255 }
  validates :country, length: { maximum: 255 }
  validates :phone, length: { maximum: 255 }

  scope :active, -> { where(inactive: false) }

  def name
    "#{street_address}, #{city}, #{state} #{zip_code}"
  end

  # Unknown is a recorded answer, not a known one, so a flow that asks what kind of
  # address this is still has to ask.
  def known_type?
    address_type.present? && address_type != UNKNOWN_CONTACT_TYPE
  end

  private

  # Every address carries a type, so one saved without an answer says so. Rows written
  # before this keep their blank until something saves them.
  def type_as_unknown
    self.address_type = UNKNOWN_CONTACT_TYPE if address_type.blank?
  end
end
