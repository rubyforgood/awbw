require "rails_helper"

RSpec.describe PersonServices::CaptureFromSubmission do
  let(:person) { create(:person) }

  describe "the mailing address" do
    it "saves a new address with no ZIP or street as blank" do
      described_class.call(person:, answers: { "mailing_city" => "Springfield", "mailing_state" => "IL" })

      expect(person.addresses.sole).to have_attributes(city: "Springfield", street_address: "", zip_code: "")
    end

    it "keeps a saved ZIP and street when a submission skips them" do
      address = create(:address, addressable: person, city: "Springfield", state: "IL", street_address: "1 Old Rd", zip_code: "62701")

      described_class.call(person:, answers: { "mailing_city" => "Springfield", "mailing_state" => "IL" })

      expect(address.reload).to have_attributes(street_address: "1 Old Rd", zip_code: "62701")
    end

    it "overwrites the ZIP and street a submission gives" do
      address = create(:address, addressable: person, city: "Springfield", state: "IL", street_address: "1 Old Rd", zip_code: "62701")

      described_class.call(person:, answers: { "mailing_city" => "Springfield", "mailing_state" => "IL",
                                               "mailing_street" => "2 New St", "mailing_zip" => "62702" })

      expect(address.reload).to have_attributes(street_address: "2 New St", zip_code: "62702")
    end

    it "reports each saved value it replaced" do
      create(:address, addressable: person, city: "Springfield", state: "IL", street_address: "1 Old Rd", zip_code: "62701")
      person.update!(pronouns: "she/her")

      capture = described_class.new(person:, answers: { "mailing_city" => "Springfield", "mailing_state" => "IL",
                                                        "mailing_street" => "2 New St", "pronouns" => "they/them" })
      capture.call

      expect(capture.replaced.map { |change| [ change.label, change.saved, change.submitted ] }).to contain_exactly(
        [ "Mailing address street address", "1 Old Rd", "2 New St" ], [ "Pronouns", "she/her", "they/them" ]
      )
    end

    it "fills a new address's country, county and locality from its state and ZIP" do
      FmPostalCode.create!(fm_id: "93701", data: { "City" => "Fresno", "State" => "CA", "County" => "Fresno" })

      described_class.call(person:, answers: { "mailing_city" => "Fresno", "mailing_state" => "CA", "mailing_zip" => "93701" })

      expect(person.addresses.sole).to have_attributes(country: "United States", county: "Fresno", locality: "Central CA")
    end
  end

  describe "the professional license" do
    it "adds a license from the answers, moving a typed license type out of the number" do
      described_class.call(person:, answers: { "license_number" => "LCSW 12345", "license_issuing_state" => "CA",
                                               "license_expires_on" => "2028-06-30" })

      expect(person.professional_licenses.sole)
        .to have_attributes(kind: "LCSW", number: "12345", issuing_state: "CA", expires_on: Date.new(2028, 6, 30))
    end

    it "saves nothing without a license number" do
      described_class.call(person:, answers: { "license_kind" => "LCSW", "license_issuing_state" => "CA" })

      expect(person.professional_licenses).to be_empty
    end

    it "updates the license on file with that number rather than adding another" do
      license = create(:professional_license, person:, kind: "LMFT", number: "999", expires_on: Date.new(2026, 1, 1))

      described_class.call(person:, answers: { "license_number" => "999", "license_expires_on" => "2029-01-01" })

      expect(person.professional_licenses.sole).to eq(license)
      expect(license.reload.expires_on).to eq(Date.new(2029, 1, 1))
    end

    it "fills in a number-pending placeholder license" do
      placeholder = create(:professional_license, person:, kind: nil, number: nil)

      described_class.call(person:, answers: { "license_number" => "555", "license_kind" => "LPCC" })

      expect(person.professional_licenses.sole).to eq(placeholder)
      expect(placeholder.reload).to have_attributes(kind: "LPCC", number: "555")
    end

    it "adds a second license for the same number under a different type" do
      create(:professional_license, person:, kind: "LMFT", number: "999")

      described_class.call(person:, answers: { "license_number" => "999", "license_kind" => "LCSW" })

      expect(person.professional_licenses.pluck(:kind)).to contain_exactly("LMFT", "LCSW")
    end

    it "reads the license questions off a standalone form" do
      form = FormBuilderService.new(name: "License", sections: %i[professional_license]).call
      number_field = form.form_fields.find_by!(field_identifier: "license_number")

      described_class.call(person:, form:, form_params: { number_field.id.to_s => "777" })

      expect(person.professional_licenses.sole.number).to eq("777")
    end
  end
end
