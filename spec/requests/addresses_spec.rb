require "rails_helper"

RSpec.describe "Addresses", type: :request do
  before { sign_in create(:user, :admin) }

  describe "GET /addresses/options" do
    let(:person) { create(:person) }
    let!(:older) { create(:address, addressable: person, street_address: "1 Old St") }
    let!(:newer) { create(:address, addressable: person, street_address: "2 New St") }

    it "returns the active addresses newest first" do
      get "/addresses/options", params: { addressable_sgid: person.to_sgid.to_s }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["addresses"].map { |a| a["id"] }).to eq([ newer.id, older.id ])
      expect(response.parsed_body["addresses"].first["label"]).to include("2 New St")
    end

    it "leaves out inactive addresses" do
      older.update!(inactive: true)

      get "/addresses/options", params: { addressable_sgid: person.to_sgid.to_s }

      expect(response.parsed_body["addresses"].map { |a| a["id"] }).to eq([ newer.id ])
    end

    it "returns an empty list for an invoicee with no addresses" do
      get "/addresses/options", params: { addressable_sgid: create(:person).to_sgid.to_s }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["addresses"]).to eq([])
    end

    it "returns an empty list for an unresolvable signed id" do
      get "/addresses/options", params: { addressable_sgid: "not-a-real-sgid" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["addresses"]).to eq([])
    end
  end
end
