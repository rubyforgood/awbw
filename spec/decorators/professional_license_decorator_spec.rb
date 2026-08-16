require "rails_helper"

RSpec.describe ProfessionalLicenseDecorator do
  describe "#expiry_badge" do
    it "reads as no expiration date when none is on file" do
      badge = build(:professional_license, expires_on: nil).decorate.expiry_badge
      expect(badge.label).to eq("No expiration date")
    end

    it "reads as active with the future expiry month" do
      badge = build(:professional_license, expires_on: Date.new(2099, 4, 10)).decorate.expiry_badge
      expect(badge.label).to eq("Active (until Apr 2099)")
    end

    it "reads as expired with the past expiry month" do
      badge = build(:professional_license, expires_on: Date.new(2024, 4, 10)).decorate.expiry_badge
      expect(badge.label).to eq("Expired (Apr 2024)")
    end
  end

  describe "CE hours issued" do
    let(:person) { create(:person) }
    let(:license) { create(:professional_license, person: person) }

    def register(hours:, sent_at:)
      registration = create(:event_registration, registrant: person)
      create(:continuing_education_registration,
        event_registration: registration,
        professional_license: license,
        hours: hours,
        certificate_sent_at: sent_at)
    end

    it "sums only issued certificates, splitting this year from all years" do
      register(hours: 6, sent_at: Time.current)
      register(hours: 4, sent_at: 2.years.ago)
      register(hours: 12, sent_at: nil)

      expect(license.decorate.ce_hours_issued_this_year).to eq(6)
      expect(license.decorate.ce_hours_issued_all_years).to eq(10)
    end

    it "returns 0 when nothing has been issued" do
      register(hours: 6, sent_at: nil)

      expect(license.decorate.ce_hours_issued_this_year).to eq(0)
      expect(license.decorate.ce_hours_issued_all_years).to eq(0)
    end

    it "keeps a fractional total" do
      register(hours: 1.5, sent_at: Time.current)

      expect(license.decorate.ce_hours_issued_all_years).to eq(1.5)
    end
  end
end
