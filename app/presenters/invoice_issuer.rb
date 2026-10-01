# Single source of truth for the organization that issues invoices and receipts:
# its name, address, email, and the "make checks payable to" note. Reads the
# admin-flagged system organization when it supplies a field, falling back to the
# deployment's ENV configuration. Only the header address carries a built-in
# default, because ORGANIZATION_ADDRESS is newer than the deployments reading it.
class InvoiceIssuer
  DEFAULT_ADDRESS_LINES = [ "1029 1/2 W 24th St", "Los Angeles, CA 90007" ].freeze

  def self.current
    new(Organization.awbw)
  end

  def initialize(organization = nil)
    @organization = organization
  end

  def name
    @organization&.name.presence || ENV.fetch("ORGANIZATION_NAME", "A Window Between Worlds")
  end

  def address_lines
    Address.display_lines_for(@organization).presence || env_address_lines.presence || DEFAULT_ADDRESS_LINES
  end

  # Where checks are mailed, which need not be the office address on the header.
  # Empty unless an address is flagged, so callers can keep their own wording.
  def remittance_address_lines
    Address.display_lines_for(@organization, role: :remittance)
  end

  def email = AppMailbox.info
  def tax_id = @organization&.tax_id.presence

  def payable_to_note
    "Please make checks payable to #{name}"
  end

  private

  # ORGANIZATION_ADDRESS holds the display lines separated by "|" (a comma can't be
  # the delimiter — the city/state/zip line contains one).
  def env_address_lines
    ENV["ORGANIZATION_ADDRESS"].to_s.split("|").map(&:strip).reject(&:blank?)
  end
end
