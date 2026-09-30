# Single source of truth for the organization that issues invoices and receipts:
# its name, address, email, and the "make checks payable to" note. Reads from the
# AWBW Organization record when a field is set (so admins can edit it in-app),
# falling back to the deployment's ENV configuration and then to these defaults,
# so a header field is never blank on a financial document.
class InvoiceIssuer
  DEFAULT_NAME = "A Window Between Worlds".freeze
  DEFAULT_ADDRESS_LINES = [ "1029 1/2 W 24th St", "Los Angeles, CA 90007" ].freeze
  DEFAULT_EMAIL = "programs@awbw.org".freeze

  def self.current
    new(Organization.awbw)
  end

  def initialize(organization = nil)
    @organization = organization
  end

  def name
    @organization&.name.presence || ENV.fetch("ORGANIZATION_NAME", DEFAULT_NAME)
  end

  def address_lines
    organization_address_lines.presence || env_address_lines.presence || DEFAULT_ADDRESS_LINES
  end

  def email
    @organization&.email.presence ||
      ENV["ORGANIZATION_INVOICE_EMAIL"].presence ||
      ENV.fetch("REPLY_TO_EMAIL", DEFAULT_EMAIL)
  end

  def payable_to_note
    "Please make checks payable to #{name}"
  end

  private

  # ORGANIZATION_ADDRESS holds the display lines separated by "|" (a comma can't be
  # the delimiter — the city/state/zip line contains one).
  def env_address_lines
    ENV["ORGANIZATION_ADDRESS"].to_s.split("|").map(&:strip).reject(&:blank?)
  end

  def organization_address_lines
    address = @organization&.addresses&.active&.first
    return [] unless address

    city_line = [ address.city.presence,
                  [ address.state.presence, address.zip_code.presence ].compact.join(" ").presence ]
      .compact.join(", ")
    [ address.street_address.presence, city_line.presence ].compact
  end
end
