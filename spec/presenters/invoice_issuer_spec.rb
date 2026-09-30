require "rails_helper"

RSpec.describe InvoiceIssuer do
  describe "fallbacks when no organization data is set" do
    subject(:issuer) { described_class.new(nil) }

    it "uses the default name" do
      expect(issuer.name).to eq(InvoiceIssuer::NAME)
    end

    it "uses the default address lines" do
      expect(issuer.address_lines).to eq(InvoiceIssuer::ADDRESS_LINES)
    end

    it "uses the default email" do
      expect(issuer.email).to eq(InvoiceIssuer::EMAIL)
    end

    it "builds the payable-to note from the default name" do
      expect(issuer.payable_to_note).to eq("Please make checks payable to #{InvoiceIssuer::NAME}")
    end
  end

  describe "reading from the organization when fields are set" do
    let(:organization) { create(:organization, name: "Test Org", email: "billing@test.org") }
    subject(:issuer) { described_class.new(organization) }

    before do
      create(:address, addressable: organization,
                       street_address: "123 Main St", city: "Springfield",
                       state: "IL", zip_code: "62704")
    end

    it "uses the organization name" do
      expect(issuer.name).to eq("Test Org")
    end

    it "uses the organization email" do
      expect(issuer.email).to eq("billing@test.org")
    end

    it "builds address lines from the active address" do
      expect(issuer.address_lines).to eq([ "123 Main St", "Springfield, IL 62704" ])
    end

    it "builds the payable-to note from the organization name" do
      expect(issuer.payable_to_note).to eq("Please make checks payable to Test Org")
    end
  end

  describe "partial data falls back per field" do
    let(:organization) { create(:organization, name: "Test Org", email: "") }
    subject(:issuer) { described_class.new(organization) }

    it "falls back to the default email when blank" do
      expect(issuer.email).to eq(InvoiceIssuer::EMAIL)
    end

    it "falls back to the default address when the organization has none" do
      expect(issuer.address_lines).to eq(InvoiceIssuer::ADDRESS_LINES)
    end
  end

  describe ".current" do
    it "reads from the AWBW organization" do
      awbw = create(:organization, name: ENV.fetch("ORGANIZATION_NAME", "A Window Between Worlds"))
      expect(described_class.current.name).to eq(awbw.name)
    end
  end
end
