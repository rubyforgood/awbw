class Address < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  LOCALITIES = [ "LA City", "LA County", "Southern CA", "Northern CA",
                "Central CA", "Orange County", "Outside CA", "Outside USA", "Unknown" ]
  CONTACT_TYPES = [ nil, "work", "personal", "mailing", "unknown" ].freeze
  ROLE_FLAGS = %i[invoice_address].freeze
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

  # The flag stores true or NULL, never false: the unique index enforces one flagged
  # address per owner, and an unchecked box writing false would collide with every
  # other unflagged address.
  before_save :normalize_role_flags
  before_save :demote_sibling_role_flags

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

  # The bill-to lines for an addressable: the address marked for invoices, else its
  # first active one, which is how a bill-to has always been picked.
  def self.display_lines_for(addressable)
    return [] unless addressable.respond_to?(:addresses)

    scope = addressable.addresses.active
    (scope.for_invoices.first || scope.first)&.display_lines || []
  end

  private

  def normalize_role_flags
    ROLE_FLAGS.each { |flag| self[flag] = nil unless self[flag] }
  end

  def demote_sibling_role_flags
    ROLE_FLAGS.each do |flag|
      next unless self[flag] && will_save_change_to_attribute?(flag)

      Address.where(addressable_type: addressable_type, addressable_id: addressable_id)
             .where(flag => true).where.not(id: id)
             .update_all(flag => nil, updated_at: Time.current)
    end
  end
end
