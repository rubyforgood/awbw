require "rails_helper"

RSpec.describe OtherResponse, type: :model do
  describe "validations" do
    it "has a valid factory" do
      expect(build(:other_response)).to be_valid
    end

    it "requires text" do
      expect(build(:other_response, text: "")).not_to be_valid
    end

    it "rejects an unknown kind" do
      expect(build(:other_response, kind: "nonsense")).not_to be_valid
    end

    it "rejects an unknown status" do
      expect(build(:other_response, status: "nonsense")).not_to be_valid
    end

    it "is unique per person + kind + normalized text" do
      person = create(:person)
      create(:other_response, person: person, kind: "sector", text: "Equine therapy")
      dup = build(:other_response, person: person, kind: "sector", text: "  equine therapy ")

      expect(dup).not_to be_valid
    end

    it "allows the same text for a different person" do
      create(:other_response, kind: "sector", text: "Equine therapy")
      expect(build(:other_response, kind: "sector", text: "Equine therapy")).to be_valid
    end
  end

  describe "normalization" do
    it "derives normalized_text from text on save" do
      response = create(:other_response, text: "  Equine Therapy  ")
      expect(response.normalized_text).to eq("equine therapy")
    end
  end

  describe "scopes" do
    it ".visible returns only pending and kept" do
      pending = create(:other_response)
      kept = create(:other_response, :kept)
      create(:other_response, :dismissed)
      create(:other_response, :promoted)

      expect(OtherResponse.visible).to contain_exactly(pending, kept)
    end
  end

  describe "#dismiss! / #keep!" do
    it "transitions status" do
      response = create(:other_response)
      response.dismiss!
      expect(response.reload.status).to eq("dismissed")
      response.keep!
      expect(response.reload.status).to eq("kept")
    end
  end
end
