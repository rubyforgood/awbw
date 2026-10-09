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

    it "has no address with nothing configured" do
      expect(issuer.address_lines).to eq([])
      expect(issuer.remittance_address_lines).to eq([])
    end

    it "has no tax id to offer" do
      expect(issuer.tax_id).to be_nil
    end
  end

  describe "resolving the issuer addresses" do
    let(:organization) { create(:organization) }

    def address_for(organization, **attrs)
      create(:address, { addressable: organization, street_address: "100 Main St",
                         city: "Anytown", state: "CA", zip_code: "90001" }.merge(attrs))
    end

    it "takes the header address from the address the Setting points at" do
      Setting.create!(organization: organization, return_address: address_for(organization))

      expect(described_class.current.address_lines).to eq([ "100 Main St", "Anytown, CA 90001" ])
    end

    it "falls back to the organization's flagged invoice address" do
      address_for(organization, invoice_address: true, street_address: "7 Flagged St",
                                city: "Townsville", zip_code: "90002")
      Setting.create!(organization: organization)

      expect(described_class.current.address_lines).to eq([ "7 Flagged St", "Townsville, CA 90002" ])
    end

    it "takes the remittance address from the address the Setting points at" do
      Setting.create!(organization: organization,
                      remittance_address: address_for(organization, street_address: "9 Checks Ln",
                                                                    city: "Elsewhere", zip_code: "90000"))

      expect(described_class.current.remittance_address_lines).to eq([ "9 Checks Ln", "Elsewhere, CA 90000" ])
    end
  end

  describe "reading from the chosen organization" do
    let(:organization) { create(:organization, name: "Test Org", tax_id: "12-3456789") }
    subject(:issuer) { described_class.new(organization) }

    it "uses the organization name" do
      expect(issuer.name).to eq("Test Org")
    end

    it "uses the organization tax id" do
      expect(issuer.tax_id).to eq("12-3456789")
    end

    it "builds the payable-to note from the organization name" do
      expect(issuer.payable_to_note).to eq("Please make checks payable to Test Org")
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
