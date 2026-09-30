require "rails_helper"

RSpec.describe InvoiceIssuer do
  describe "falling back to ENV when no organization data is set" do
    subject(:issuer) { described_class.new(nil) }

    it "reads the name from ORGANIZATION_NAME" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ORGANIZATION_NAME", anything).and_return("Env Org")
      expect(issuer.name).to eq("Env Org")
    end

    it "reads the email from ORGANIZATION_EMAIL" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ORGANIZATION_EMAIL", anything).and_return("billing@env.org")
      expect(issuer.email).to eq("billing@env.org")
    end

    it "splits ORGANIZATION_ADDRESS on '|' into display lines" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ORGANIZATION_ADDRESS", anything)
        .and_return("100 Main St|Anytown, CA 90001")
      expect(issuer.address_lines).to eq([ "100 Main St", "Anytown, CA 90001" ])
    end

    it "builds the payable-to note from the resolved name" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ORGANIZATION_NAME", anything).and_return("Env Org")
      expect(issuer.payable_to_note).to eq("Please make checks payable to Env Org")
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

    it "falls back to ENV for a blank email" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ORGANIZATION_EMAIL", anything).and_return("fallback@env.org")
      expect(issuer.email).to eq("fallback@env.org")
    end

    it "falls back to ENV when the organization has no address" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ORGANIZATION_ADDRESS", anything).and_return("1 Fallback Way|Elsewhere, CA 90000")
      expect(issuer.address_lines).to eq([ "1 Fallback Way", "Elsewhere, CA 90000" ])
    end
  end

  describe ".current" do
    it "reads from the AWBW organization" do
      awbw = create(:organization, name: ENV.fetch("ORGANIZATION_NAME", "A Window Between Worlds"))
      expect(described_class.current.name).to eq(awbw.name)
    end
  end
end
