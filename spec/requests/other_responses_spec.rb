require "rails_helper"

RSpec.describe "OtherResponses", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "GET /other_responses" do
    it "requires an admin" do
      get other_responses_path
      expect(response).not_to have_http_status(:ok)
    end

    it "groups the same value across people with a count" do
      sign_in admin
      alice = create(:person)
      bob = create(:person)
      create(:other_response, person: alice, kind: "sector", text: "Equine therapy")
      create(:other_response, person: bob, kind: "sector", text: "equine therapy")
      create(:other_response, :dismissed, person: bob, kind: "sector", text: "Hidden one")

      get other_responses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Equine therapy")
      expect(response.body).not_to include("Hidden one")
    end

    it "filters to a single status" do
      sign_in admin
      create(:other_response, kind: "sector", text: "Pending value")
      create(:other_response, :kept, kind: "sector", text: "Kept value")

      get other_responses_path(status: "kept")

      expect(response.body).to include("Kept value")
      expect(response.body).not_to include("Pending value")
    end
  end

  describe "POST /other_responses/curate (bulk)" do
    it "requires an admin" do
      create(:other_response, kind: "sector", text: "Equine therapy")
      post curate_other_responses_path, params: { normalized_text: "equine therapy", status: "dismissed" }
      expect(response).not_to have_http_status(:ok)
    end

    it "keeps every visible person who typed the value" do
      sign_in admin
      one = create(:other_response, kind: "sector", text: "Equine therapy")
      two = create(:other_response, kind: "sector", text: "equine therapy")

      post curate_other_responses_path,
           params: { normalized_text: "equine therapy", status: "kept" }

      expect(one.reload.status).to eq("kept")
      expect(two.reload.status).to eq("kept")
    end

    it "dismisses every visible person who typed the value" do
      sign_in admin
      response_record = create(:other_response, :kept, kind: "sector", text: "Equine therapy")

      post curate_other_responses_path,
           params: { normalized_text: "equine therapy", status: "dismissed" }

      expect(response_record.reload.status).to eq("dismissed")
    end

    it "rejects an unsupported status" do
      sign_in admin
      response_record = create(:other_response, kind: "sector", text: "Equine therapy")

      post curate_other_responses_path,
           params: { normalized_text: "equine therapy", status: "promoted" }

      expect(response).to redirect_to(other_responses_path)
      expect(response_record.reload.status).to eq("pending")
    end
  end

  describe "PATCH /other_responses/:id (dismiss)" do
    it "dismisses the response and returns to the person edit page" do
      sign_in admin
      response_record = create(:other_response, kind: "sector", text: "Equine therapy")

      patch other_response_path(response_record),
            params: { other_response: { status: "dismissed" }, return_to: "person_edit" }

      expect(response).to redirect_to(edit_person_path(response_record.person))
      expect(response_record.reload.status).to eq("dismissed")
    end
  end

  describe "POST /other_responses/promote" do
    it "requires an admin" do
      sector = create(:sector, name: "Equine Therapy")
      create(:other_response, kind: "sector", text: "Equine therapy")
      post promote_other_responses_path, params: { normalized_text: "equine therapy", sector_id: sector.id }
      expect(response).not_to have_http_status(:ok)
    end

    it "tags every non-dismissed person and marks the responses promoted" do
      sign_in admin
      sector = create(:sector, name: "Equine Therapy")
      kept = create(:other_response, person: create(:person), kind: "sector", text: "Equine therapy")
      dismissed = create(:other_response, :dismissed, person: create(:person), kind: "sector", text: "Equine therapy")

      post promote_other_responses_path,
           params: { normalized_text: "equine therapy", sector_id: sector.id }

      expect(kept.reload.status).to eq("promoted")
      expect(kept.person.sectors).to include(sector)
      expect(dismissed.reload.status).to eq("dismissed")
      expect(dismissed.person.sectors).not_to include(sector)
    end

    it "mints a new published sector when given a name" do
      sign_in admin
      person = create(:person)
      create(:other_response, person: person, kind: "sector", text: "Equine therapy")

      expect {
        post promote_other_responses_path,
             params: { normalized_text: "equine therapy", new_sector_name: "Equine therapy" }
      }.to change(Sector, :count).by(1)

      sector = Sector.find_by(name: "Equine therapy")
      expect(sector.published).to be(true)
      expect(person.sectors).to include(sector)
    end
  end
end
