# Single source of truth for the organization that issues invoices and receipts:
# its name, tax id, addresses, email, and the "make checks payable to" note. The
# name and tax id come from the admin-chosen system organization; the addresses
# and email are app-wide settings (which themselves fall back to the organization's
# flagged addresses and to ENV).
class InvoiceIssuer
  def self.current
    new(Setting.app_organization)
  end

  def initialize(organization = nil)
    @organization = organization
  end

  def name
    @organization&.name.presence || Setting.organization_name
  end

  def address_lines = Setting.organization_address_lines

  # Where checks are mailed: the header carries the return address, checks go to the
  # remittance address.
  def remittance_address_lines = Setting.remittance_address_lines

  def email = Setting.info_email
  def tax_id = @organization&.tax_id.presence

  def payable_to_note
    "Please make checks payable to #{name}"
  end
end
