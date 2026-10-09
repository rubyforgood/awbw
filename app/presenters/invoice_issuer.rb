# Single source of truth for the organization that issues invoices and receipts:
# its name, address, email, and the "make checks payable to" note. Reads the
# admin-flagged system organization when it supplies a field, falling back to
# Setting and then to a built-in default, so an unconfigured deployment still
# prints a usable document.
class InvoiceIssuer
  DEFAULT_ADDRESS_LINES = [ "1029 1/2 W 24th St", "Los Angeles, CA 90007" ].freeze
  DEFAULT_REMITTANCE_ADDRESS_LINES = [ "1210 Fernside Dr.", "La Cañada, CA 91011" ].freeze

  def self.current
    new(Setting.app_organization)
  end

  def initialize(organization = nil)
    @organization = organization
  end

  def name
    @organization&.name.presence || Setting.organization_name
  end

  def address_lines
    Address.display_lines_for(@organization).presence ||
      Setting.organization_address_lines.presence ||
      DEFAULT_ADDRESS_LINES
  end

  # Where checks are mailed, which is a different address from the header: the
  # header carries the return address, checks go to the remittance address.
  def remittance_address_lines
    Address.display_lines_for(@organization, role: :remittance).presence ||
      Setting.remittance_address_lines.presence ||
      DEFAULT_REMITTANCE_ADDRESS_LINES
  end

  def email = Setting.info_email
  def tax_id = @organization&.tax_id.presence

  def payable_to_note
    "Please make checks payable to #{name}"
  end
end
