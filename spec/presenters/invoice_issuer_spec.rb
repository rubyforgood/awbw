require "rails_helper"

RSpec.describe InvoiceIssuer do
  describe "falling back to configuration when no organization is flagged" do
    subject(:issuer) { described_class.new(nil) }

    it "reads the name from ORGANIZATION_NAME" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ORGANIZATION_NAME", anything).and_return("Env Org")
      expect(issuer.name).to eq("Env Org")
    end

    it "builds the payable-to note from the resolved name" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ORGANIZATION_NAME", anything).and_return("Env Org")
      expect(issuer.payable_to_note).to eq("Please make checks payable to Env Org")
    end

    it "takes the header address from the Setting row" do
      Setting.create!(organization_address: "100 Main St\nAnytown, CA 90001")

      expect(issuer.address_lines).to eq([ "100 Main St", "Anytown, CA 90001" ])
    end

    it "degrades to the built-in return address with nothing stored" do
      expect(issuer.address_lines).to eq([ "1029 1/2 W 24th St", "Los Angeles, CA 90007" ])
    end

    it "takes the remittance address from the Setting row" do
      Setting.create!(remittance_address: "9 Checks Ln\nElsewhere, CA 90000")

      expect(issuer.remittance_address_lines).to eq([ "9 Checks Ln", "Elsewhere, CA 90000" ])
    end

    it "degrades to the built-in remittance address, which is not the return address" do
      expect(issuer.remittance_address_lines).to eq([ "1210 Fernside Dr.", "La Cañada, CA 91011" ])
      expect(issuer.remittance_address_lines).not_to eq(issuer.address_lines)
    end

    it "has no tax id to offer" do
      expect(issuer.tax_id).to be_nil
    end
  end

  describe "reading from the flagged organization" do
    let(:organization) { create(:organization, name: "Test Org", tax_id: "12-3456789") }
    subject(:issuer) { described_class.new(organization) }

    before do
      create(:address, addressable: organization,
                       street_address: "123 Main St", city: "Springfield",
                       state: "IL", zip_code: "62704")
    end

    it "uses the organization name" do
      expect(issuer.name).to eq("Test Org")
    end

    it "uses the organization tax id" do
      expect(issuer.tax_id).to eq("12-3456789")
    end

    it "builds header address lines from its address" do
      expect(issuer.address_lines).to eq([ "123 Main St", "Springfield, IL 62704" ])
    end

    it "prefers an address flagged for invoices" do
      create(:address, addressable: organization, invoice_address: true,
                       street_address: "9 Billing Rd", city: "Shelbyville",
                       state: "IL", zip_code: "62565")

      expect(issuer.address_lines).to eq([ "9 Billing Rd", "Shelbyville, IL 62565" ])
    end

    it "builds the payable-to note from the organization name" do
      expect(issuer.payable_to_note).to eq("Please make checks payable to Test Org")
    end

    it "prefers an address flagged for remittance over the built-in one" do
      create(:address, addressable: organization, remittance_address: true,
                       street_address: "9 Checks Ln", city: "La Canada",
                       state: "CA", zip_code: "91011")

      expect(described_class.new(organization.reload).remittance_address_lines)
        .to eq([ "9 Checks Ln", "La Canada, CA 91011" ])
    end

    it "falls back to the Setting row when the organization has no address" do
      organization.addresses.destroy_all
      Setting.create!(organization_address: "1 Fallback Way\nElsewhere, CA 90000")

      expect(described_class.new(organization.reload).address_lines)
        .to eq([ "1 Fallback Way", "Elsewhere, CA 90000" ])
    end
  end

  describe "#email" do
    it "comes from configuration, not the organization record" do
      organization = create(:organization, email: "org-record@test.org")
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("INFO_EMAIL").and_return("info@example.test")

      expect(described_class.new(organization).email).to eq("info@example.test")
    end
  end

  describe ".current" do
    # Asserts on tax_id, not name: the ENV name fallback would match a found record's
    # name anyway, so only a record-only field proves the lookup ran.
    it "reads the organization the Setting row points at" do
      organization = create(:organization, name: "Renamed Since Launch", tax_id: "99-9999999")
      Setting.create!(organization: organization)

      expect(described_class.current.tax_id).to eq("99-9999999")
    end
  end
end
