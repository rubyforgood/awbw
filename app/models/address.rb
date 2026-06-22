class Address < ApplicationRecord
  LOCALITIES = [ "LA City", "LA County", "Southern CA", "Northern CA",
                "Central CA", "Orange County", "Outside CA", "Outside USA", "Unknown" ]
  CONTACT_TYPES = [ nil, "work", "personal", "mailing", "unknown" ].freeze

  # The canonical country value that flags an address as domestic. It drives the
  # form's US-state-dropdown vs. free-text-region toggle and the state validation
  # below, so the dropdown option and this check share one constant.
  US_COUNTRY = "United States".freeze

  belongs_to :addressable, polymorphic: true, touch: true
  # Affiliations that point to this address as their organization address. Nullify
  # the link rather than block deletion when an org address is removed.
  has_many :affiliations, foreign_key: :organization_address_id, dependent: :nullify, inverse_of: :organization_address

  validates :locality, presence: true
  validates :city, presence: true
  validates :state, presence: true
  # US addresses must use a recognized state abbreviation; international addresses
  # store a free-form region, so they only need a value (presence above). The check
  # is case-insensitive to tolerate legacy lowercase abbreviations (e.g. "tx").
  validate :state_is_a_us_state, if: :united_states?
  validates :address_type, inclusion: { in: CONTACT_TYPES }

  scope :active, -> { where(inactive: false) }

  # A blank or "United States" country is treated as domestic; any other country
  # is international and exempt from the US-state-abbreviation check.
  def united_states?
    country.blank? || country == US_COUNTRY
  end

  # US states are stored as abbreviations (e.g. "CA"); international addresses may
  # store a free-form region (e.g. "Ontario"). A blank state is dropped so the
  # rendered name never carries a stray separator.
  def name
    region = [ state, zip_code ].compact_blank.join(" ")
    [ street_address, city, region ].compact_blank.join(", ")
  end

  private

  def state_is_a_us_state
    return if state.blank?
    return if UsState::ABBREVIATIONS.include?(state.upcase)

    errors.add(:state, "is not a valid US state")
  end
end
