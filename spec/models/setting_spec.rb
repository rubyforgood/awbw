require "rails_helper"

RSpec.describe Setting do
  describe "the single row" do
    it "answers every reader before a row exists" do
      expect(described_class.count).to eq(0)
      expect(described_class.current).not_to be_persisted
      expect(described_class.invoice_prefix).to eq("INV")
    end

    it "refuses a second row" do
      described_class.create!

      expect { described_class.create! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "stops serving a stale memo once the row is saved" do
      expect(described_class.invoice_prefix).to eq("INV")

      described_class.create!(invoice_prefix: "AWBW")

      expect(described_class.invoice_prefix).to eq("AWBW")
    end
  end

  describe ".app_organization" do
    it "is the organization the row points at, whatever it is named" do
      chosen = create(:organization, name: "Renamed Since Launch")
      create(:organization, name: described_class.organization_name)
      described_class.create!(organization: chosen)

      expect(described_class.app_organization).to eq(chosen)
    end

    it "falls back to the organization named by ORGANIZATION_NAME when the row points nowhere" do
      named = create(:organization, name: described_class.organization_name)
      create(:organization, name: "Some Partner Org")

      expect(described_class.app_organization).to eq(named)
    end

    it "is nil when nothing is chosen and no name matches" do
      create(:organization, name: "Some Partner Org")

      expect(described_class.app_organization).to be_nil
    end
  end

  describe "falling back through the row, then ENV, then a default" do
    it "prefers the stored value" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("INFO_EMAIL").and_return("env@example.test")
      described_class.create!(info_email: "stored@example.test")

      expect(described_class.info_email).to eq("stored@example.test")
    end

    it "uses ENV when the field is blank" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("INFO_EMAIL").and_return("env@example.test")
      described_class.create!(info_email: "")

      expect(described_class.info_email).to eq("env@example.test")
    end

    it "degrades to the built-in defaults with nothing configured" do
      expect(described_class.organization_name).to eq("A Window Between Worlds")
      expect(described_class.invoice_prefix).to eq("INV")
      expect(described_class.annual_membership_cents).to eq(2500)
      expect(described_class.membership_renewal_window_days).to eq(30)
      expect(described_class.membership_grace_period_days).to eq(30)
    end

    it "lets a stored zero win over the default" do
      described_class.create!(membership_grace_period_days: 0)

      expect(described_class.membership_grace_period_days).to eq(0)
    end
  end

  describe "the mailbox chain" do
    def stub_env(values)
      allow(ENV).to receive(:[]).and_call_original
      values.each { |key, value| allow(ENV).to receive(:[]).with(key).and_return(value) }
    end

    it "prefers the dedicated vars over REPLY_TO_EMAIL" do
      stub_env("PROGRAMS_EMAIL" => "programs@example.test",
               "NO_REPLY_EMAIL" => "no-reply@example.test",
               "REPLY_TO_EMAIL" => "legacy@example.test")

      expect(described_class.programs_email).to eq("programs@example.test")
      expect(described_class.no_reply_email).to eq("no-reply@example.test")
    end

    it "falls back to REPLY_TO_EMAIL so deployments keep working before the new vars are set" do
      stub_env("PROGRAMS_EMAIL" => nil, "NO_REPLY_EMAIL" => nil, "REPLY_TO_EMAIL" => "legacy@example.test")

      expect(described_class.programs_email).to eq("legacy@example.test")
      expect(described_class.no_reply_email).to eq("legacy@example.test")
    end

    it "treats a blank var as unset rather than sending from an empty address" do
      stub_env("PROGRAMS_EMAIL" => "", "REPLY_TO_EMAIL" => "legacy@example.test")

      expect(described_class.programs_email).to eq("legacy@example.test")
    end

    it "falls through the contact mailbox to the programs mailbox" do
      stub_env("INFO_EMAIL" => nil, "PROGRAMS_EMAIL" => "programs@example.test")

      expect(described_class.info_email).to eq("programs@example.test")
    end

    it "prefers a stored mailbox over the configured one" do
      stub_env("PROGRAMS_EMAIL" => "programs@example.test")
      described_class.create!(programs_email: "stored@example.test")

      expect(described_class.programs_email).to eq("stored@example.test")
    end
  end

  describe "validations" do
    it "rejects a malformed email" do
      setting = described_class.new(info_email: "not-an-email")

      expect(setting).not_to be_valid
      expect(setting.errors[:info_email]).to include("must be a valid email address")
    end

    it "rejects a negative window" do
      expect(described_class.new(membership_renewal_window_days: -1)).not_to be_valid
    end
  end

  describe "addresses" do
    let(:organization) { create(:organization) }

    def address_for(organization, **attrs)
      create(:address, { addressable: organization, street_address: "100 Main St",
                         city: "Anytown", state: "CA", zip_code: "90001" }.merge(attrs))
    end

    it "reads the return address the row points at, a line at a time" do
      described_class.create!(organization: organization, return_address: address_for(organization))

      expect(described_class.organization_address_lines).to eq([ "100 Main St", "Anytown, CA 90001" ])
    end

    it "reads the remittance address separately from the return address" do
      described_class.create!(organization: organization,
                              return_address: address_for(organization),
                              remittance_address: address_for(organization, street_address: "9 Checks Ln",
                                                                            city: "Elsewhere", zip_code: "90000"))

      expect(described_class.remittance_address_lines).to eq([ "9 Checks Ln", "Elsewhere, CA 90000" ])
    end

    it "falls back to the app organization's invoice address when the row points nowhere" do
      address_for(organization, invoice_address: true, street_address: "7 Flagged St",
                                city: "Townsville", zip_code: "90002")
      described_class.create!(organization: organization)

      expect(described_class.organization_address_lines).to eq([ "7 Flagged St", "Townsville, CA 90002" ])
    end

    it "mails cheques to the return address when no remittance address is set" do
      described_class.create!(organization: organization, return_address: address_for(organization))

      expect(described_class.remittance_address_lines).to eq([ "100 Main St", "Anytown, CA 90001" ])
    end

    it "is empty with no organization and nothing stored" do
      expect(described_class.organization_address_lines).to eq([])
      expect(described_class.remittance_address_lines).to eq([])
    end
  end
end
