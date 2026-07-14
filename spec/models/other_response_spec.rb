require "rails_helper"

RSpec.describe OtherResponse, type: :model do
  describe "validations" do
    it "has a valid factory" do
      expect(build(:other_response)).to be_valid
    end

    it "requires text" do
      expect(build(:other_response, text: "")).not_to be_valid
    end

    it "requires a field_identifier" do
      expect(build(:other_response, field_identifier: "")).not_to be_valid
    end

    it "is unique per person + field + normalized text" do
      person = create(:person)
      create(:other_response, owner: person, field_identifier: "additional_sectors", text: "Equine therapy")
      dup = build(:other_response, owner: person, field_identifier: "additional_sectors", text: "  equine therapy ")

      expect(dup).not_to be_valid
    end

    it "allows the same text on a different question" do
      person = create(:person)
      create(:other_response, owner: person, field_identifier: "additional_sectors", text: "Equine therapy")
      other_question = build(:other_response, owner: person, field_identifier: "how_did_you_hear", text: "Equine therapy")

      expect(other_question).to be_valid
    end

    it "allows the same text for a different person" do
      create(:other_response, field_identifier: "additional_sectors", text: "Equine therapy")
      expect(build(:other_response, field_identifier: "additional_sectors", text: "Equine therapy")).to be_valid
    end
  end

  describe "kind derivation" do
    it "is sector for a sector field" do
      expect(create(:other_response, field_identifier: "additional_sectors").kind).to eq("sector")
    end

    it "is organization_type for the agency_type field" do
      expect(create(:other_response, :organization_type).kind).to eq("organization_type")
    end

    it "is generic for any other field" do
      expect(create(:other_response, field_identifier: "how_did_you_hear").kind).to eq("generic")
    end
  end

  describe "normalization" do
    it "derives normalized_text from text on save" do
      response = create(:other_response, text: "  Equine Therapy  ")
      expect(response.normalized_text).to eq("equine therapy")
    end
  end

  describe "scopes and #promotable?" do
    it ".visible returns only pending and kept" do
      pending = create(:other_response)
      kept = create(:other_response, :kept)
      create(:other_response, :dismissed)
      create(:other_response, :promoted)

      expect(OtherResponse.visible).to contain_exactly(pending, kept)
    end

    it "only sector responses are promotable" do
      expect(create(:other_response).promotable?).to be(true)
      expect(create(:other_response, :generic).promotable?).to be(false)
      expect(create(:other_response, :organization_type).promotable?).to be(false)
    end

    it "an organization owns its organization-type response" do
      response = create(:other_response, :organization_type)
      expect(response.owner).to be_a(Organization)
    end
  end

  describe "#registration_organizations" do
    it "returns the org the person registered with, via the source answer's event" do
      person = create(:person)
      event = create(:event)
      organization = create(:organization)
      registration = create(:event_registration, registrant: person, event: event)
      create(:event_registration_organization, event_registration: registration, organization: organization)
      submission = create(:form_submission, person: person, event: event)
      answer = create(:form_answer, form_submission: submission,
                      form_field: create(:form_field, field_identifier: "additional_sectors"),
                      submitted_answer: "Other: Equine therapy")
      response = create(:other_response, owner: person, text: "Equine therapy", source_form_answer: answer)

      expect(response.registration_organizations).to contain_exactly(organization)
    end

    it "is empty when there's no source form answer" do
      expect(create(:other_response, source_form_answer: nil).registration_organizations).to be_empty
    end
  end

  describe "#review_anchor" do
    it "buckets sectors by kind, parameterized" do
      expect(create(:other_response, text: "Equine Therapy").review_anchor).to eq("other-sector-equine-therapy")
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
