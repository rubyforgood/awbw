require "rails_helper"

RSpec.describe ProfessionalLicenseDecorator do
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
