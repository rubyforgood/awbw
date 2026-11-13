require "rails_helper"

RSpec.describe PersonServices::CaptureFromSubmission do
  let(:person) { create(:person) }

  describe "the phone" do
    it "reuses the same number on file despite formatting, making it the only primary" do
      other = create(:contact_method, contactable: person, kind: :phone, value: "555-400-2000", primary: true)
      same = create(:contact_method, contactable: person, kind: :phone, value: "+1 (555) 400-1000", primary: false)

      capture = described_class.new(person:, answers: { "phone" => "555 400 1000" })
      capture.call

      expect(person.contact_methods.where(kind: :phone).count).to eq(2)
      expect(same.reload).to have_attributes(primary: true, inactive: false)
      expect(other.reload).to have_attributes(primary: false, inactive: true)
      expect(capture.replaced.sole).to have_attributes(label: "Primary phone", saved: "555-400-2000", submitted: "+1 (555) 400-1000")
    end

    it "adds a new number as the primary, retiring the old one" do
      old = create(:contact_method, contactable: person, kind: :phone, value: "555-400-2000", primary: true)

      described_class.call(person:, answers: { "phone" => "555-400-1000" })

      expect(old.reload).to have_attributes(primary: false, inactive: true)
      expect(person.contact_methods.find_by(value: "555-400-1000")).to be_primary
    end

    it "reports nothing when the submitted number is already the primary" do
      create(:contact_method, contactable: person, kind: :phone, value: "555-400-1000", primary: true)

      capture = described_class.new(person:, answers: { "phone" => "(555) 400-1000" })
      capture.call

      expect(capture.replaced).to be_empty
    end
  end

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

    it "updates the same-street address's ZIP and makes it primary" do
      other = create(:address, addressable: person, city: "Chicago", state: "IL", street_address: "9 Elm St", primary: true)
      address = create(:address, addressable: person, city: "Springfield", state: "IL", street_address: "1 Old Rd", zip_code: "62701")

      described_class.call(person:, answers: { "mailing_city" => "Springfield", "mailing_state" => "IL",
                                               "mailing_street" => "1 Old Road", "mailing_zip" => "62702" })

      expect(address.reload).to have_attributes(street_address: "1 Old Rd", zip_code: "62702", primary: true)
      expect(other.reload).not_to be_primary
      expect(person.addresses.count).to eq(2)
    end

    it "adds a different street in the same city as a new primary address, retiring the old one" do
      old = create(:address, addressable: person, city: "Springfield", state: "IL", street_address: "1 Old Rd", zip_code: "62701", primary: true)

      described_class.call(person:, answers: { "mailing_city" => "Springfield", "mailing_state" => "IL",
                                               "mailing_street" => "2 New St", "mailing_zip" => "62702" })

      expect(old.reload).to have_attributes(street_address: "1 Old Rd", primary: false, inactive: true)
      expect(person.addresses.find_by(street_address: "2 New St")).to have_attributes(zip_code: "62702", primary: true)
    end

    it "reports each saved value it replaced" do
      old = create(:address, addressable: person, city: "Springfield", state: "IL", street_address: "1 Old Rd", zip_code: "62701", primary: true)
      person.update!(pronouns: "she/her")

      capture = described_class.new(person:, answers: { "mailing_city" => "Springfield", "mailing_state" => "IL",
                                                        "mailing_street" => "2 New St", "pronouns" => "they/them" })
      capture.call

      expect(capture.replaced.map { |change| [ change.label, change.saved, change.submitted ] }).to contain_exactly(
        [ "Primary mailing address", old.name.squish, person.addresses.find_by(street_address: "2 New St").name.squish ],
        [ "Pronouns", "she/her", "they/them" ]
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
