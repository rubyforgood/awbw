require "rails_helper"

RSpec.describe PersonServices::CaptureFromSubmission do
  let(:person) { create(:person) }

  describe "the mailing address" do
    it "saves a new address with no ZIP or street as blank" do
      described_class.call(person:, answers: { "mailing_city" => "Springfield", "mailing_state" => "IL" })

      expect(person.addresses.sole).to have_attributes(city: "Springfield", street_address: "", zip_code: "")
    end

    it "stores the answered state and country as the dropdowns do" do
      described_class.call(person:, answers: { "mailing_city" => "Fresno", "mailing_state" => "California", "mailing_country" => "USA" })

      expect(person.addresses.sole).to have_attributes(state: "CA", country: "United States")
    end

    it "translates a country it fills on an address already on file" do
      address = create(:address, addressable: person, city: "Toronto", state: "ON", country: nil)

      described_class.call(person:, answers: { "mailing_city" => "Toronto", "mailing_state" => "ON", "mailing_country" => "can" }, overwrite: false)

      expect(address.reload.country).to eq("Canada")
    end

    it "keeps a saved ZIP and street when an overwriting submission skips them" do
      address = create(:address, addressable: person, city: "Springfield", state: "IL", street_address: "1 Old Rd", zip_code: "62701")

      described_class.call(person:, answers: { "mailing_city" => "Springfield", "mailing_state" => "IL" }, overwrite: true)

      expect(address.reload).to have_attributes(street_address: "1 Old Rd", zip_code: "62701")
    end

    it "overwrites the ZIP and street a submission gives" do
      address = create(:address, addressable: person, city: "Springfield", state: "IL", street_address: "1 Old Rd", zip_code: "62701")

      described_class.call(person:, answers: { "mailing_city" => "Springfield", "mailing_state" => "IL",
                                               "mailing_street" => "2 New St", "mailing_zip" => "62702" }, overwrite: true)

      expect(address.reload).to have_attributes(street_address: "2 New St", zip_code: "62702")
    end
  end
end
