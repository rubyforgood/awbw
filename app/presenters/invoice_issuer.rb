# Single source of truth for the organization that issues invoices and receipts:
# its name, address, email, and the "make checks payable to" note. Reads from the
# AWBW Organization record when a field is set so admins can edit it in-app,
# falling back to these constants when a field is blank.
class InvoiceIssuer
  NAME = "A Window Between Worlds"
  ADDRESS_LINES = [ "1029 1/2 W 24th St", "Los Angeles, CA 90007" ].freeze
  EMAIL = "info@awbw.org"

  def self.current
    new(Organization.awbw)
  end

  def initialize(organization = nil)
    @organization = organization
  end

  def name
    @organization&.name.presence || NAME
  end

  def address_lines
    organization_address_lines.presence || ADDRESS_LINES
  end

  def email
    @organization&.email.presence || EMAIL
  end

  def payable_to_note
    "Please make checks payable to #{name}"
  end

  private

  def organization_address_lines
    address = @organization&.addresses&.active&.first
    return [] unless address

    city_line = [ address.city.presence,
                  [ address.state.presence, address.zip_code.presence ].compact.join(" ").presence ]
      .compact.join(", ")
    [ address.street_address.presence, city_line.presence ].compact
  end
end
