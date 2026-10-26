class Address < ApplicationRecord
  include FilemakerCoded
  include OutsideUsaTypeable
  filemaker_archived_in FmAddress

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # AWBW's own geography, inherited from FileMaker's project Locality field. The California
  # regions are mapped by county in AddressLocality::CALIFORNIA_REGIONS.
  LA_CITY = "LA City"
  LA_COUNTY = "LA County"
  ORANGE_COUNTY = "Orange County"
  OUTSIDE_CA = "Outside CA"
  OUTSIDE_USA = "Outside USA"
  UNKNOWN_LOCALITY = "Unknown"
  LOCALITIES = [ LA_CITY, LA_COUNTY, "Southern CA", "Northern CA",
                "Central CA", ORANGE_COUNTY, OUTSIDE_CA, OUTSIDE_USA, UNKNOWN_LOCALITY ]
  CALIFORNIA_LOCALITIES = LOCALITIES - [ OUTSIDE_CA, OUTSIDE_USA, UNKNOWN_LOCALITY ]
  # The one spelling of the US the country dropdown carries, so a value compared or
  # copied against it matches the option rather than rendering the select blank.
  DEFAULT_COUNTRY = "United States"
  # The parts of an address someone has to type. Locality, state and country arrive on a
  # new form block already filled from the saved address, so they say nothing about
  # whether anyone touched it.
  ENTERED_FIELDS = %w[city street_address zip_code].freeze
  UNKNOWN_CONTACT_TYPE = "unknown"
  CONTACT_TYPES = [ nil, "work", "personal", "mailing", UNKNOWN_CONTACT_TYPE ].freeze
  ORGANIZATION_CONTACT_TYPES = %w[work mailing].freeze
  # USPS abbreviations for the 50 states, DC, and the US territories the atlas
  # draws — the whitelist behind every "States" breakdown, so international
  # regions (e.g. "ON", "England") are excluded (they belong to the Countries map).
  US_STATE_ABBREVIATIONS = %w[
    AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO
    MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY
    PR GU VI AS MP
  ].freeze

  belongs_to :addressable, polymorphic: true, touch: true

  typed_outside_usa :state

  # Affiliations that point to this address as their organization address. Nullify
  # the link rather than block deletion when an org address is removed.
  has_many :affiliations, foreign_key: :organization_address_id, dependent: :nullify, inverse_of: :organization_address

  before_validation :type_as_unknown
  normalizes :street_address, :city, :zip_code, :district, :county, :phone,
             with: ->(value) { value.lines.map(&:strip).compact_blank.join("\n") }

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
  scope :for_invoices, -> { where(invoice_address: true) }

  # Which of an owner's addresses stands for them when only one can, best first:
  # [ inactive?, address_type ] — a nil type matches whatever is left at that
  # active/inactive level. Work and personal swap places below the active line on
  # purpose: a current work address is the sharpest thing we know about someone,
  # and a retired one the stalest (people change jobs; home outlasts the job). A
  # retired address still beats placing them nowhere.
  #
  # Written once, in Ruby, because both the ORDER BY and Address#standing read it —
  # a hand-kept SQL twin of this list would drift the first time an order changed.
  STANDING = [
    [ false, "work" ],
    [ false, "personal" ],
    [ false, nil ],
    [ true, "personal" ],
    [ true, "work" ]
  ].freeze

  # Interpolated, not bound: every value comes from STANDING above, never a caller.
  STANDING_SQL = STANDING.map.with_index { |(inactive, type), rank|
    tests = [ "addresses.inactive = #{inactive ? 1 : 0}" ]
    tests << "addresses.address_type = '#{type}'" if type
    "WHEN #{tests.join(' AND ')} THEN #{rank}"
  }.join(" ").then { |whens| "CASE #{whens} ELSE #{STANDING.size} END" }.freeze

  # Best-standing first, then most recently edited — "latest edited" is how two
  # addresses at the same standing are told apart.
  scope :ranked_for_owner, -> { order(Arel.sql(STANDING_SQL), updated_at: :desc, id: :asc) }

  # This address's place in STANDING, for sorting an already-loaded set the same
  # way the scope sorts a query.
  def standing
    STANDING.index { |rank_inactive, type| rank_inactive == inactive? && (type.nil? || type == address_type) } || STANDING.size
  end

  # A nested-attributes block nobody filled in, which the parent drops instead of
  # building an address that can only fail validation.
  def self.unfilled_attributes?(attributes)
    attributes.slice(*ENTERED_FIELDS).values.all?(&:blank?)
  end

  def name
    "#{street_address}, #{city}, #{state} #{zip_code}"
  end

  # The two lines an invoice, receipt, or contact block prints for this address.
  def display_lines
    city_line = [ city.presence,
                  [ state.presence, zip_code.presence ].compact.join(" ").presence ]
      .compact.join(", ")
    [ street_address.presence, city_line.presence ].compact
  end

  # The bill-to lines for an addressable: its oldest address marked for invoices,
  # else its first active one, which is how a bill-to has always been picked. Oldest
  # first so marking another address doesn't move an existing bill-to.
  def self.display_lines_for(addressable)
    return [] unless addressable.respond_to?(:addresses)

    scope = addressable.addresses.active.order(:id)
    (scope.for_invoices.first || scope.first)&.display_lines || []
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
