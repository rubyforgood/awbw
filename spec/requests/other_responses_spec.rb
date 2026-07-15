require "rails_helper"

RSpec.describe "OtherResponses", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "GET /other_responses" do
    it "requires an admin" do
      get other_responses_path
      expect(response).not_to have_http_status(:ok)
    end

    it "groups the same sector value across people with a count" do
      sign_in admin
      alice = create(:person)
      bob = create(:person)
      create(:other_response, owner: alice, text: "Equine therapy")
      create(:other_response, owner: bob, text: "equine therapy")

      get other_responses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Equine therapy")
    end

    it "keeps dismissed responses in the queue (they can still be promoted later)" do
      sign_in admin
      create(:other_response, :dismissed, text: "Youth membership")

      get other_responses_path

      expect(response.body).to include("Youth membership")
    end

    it "shows generic (non-sector) responses under their question" do
      sign_in admin
      create(:other_response, :generic, text: "A friend")

      get other_responses_path

      expect(response.body).to include("A friend")
      expect(response.body).to include("How did you hear")
    end

    it "shows organization-type responses labelled, with keep/dismiss but no promote" do
      sign_in admin
      create(:other_response, :organization_type, text: "Nonprofit collective")

      get other_responses_path

      expect(response.body).to include("Nonprofit collective")
      expect(response.body).to include("Organization type")
      expect(response.body).to include("Dismiss all")
    end

    it "filters to a single status" do
      sign_in admin
      create(:other_response, text: "Pending value")
      create(:other_response, :kept, text: "Kept value")

      get other_responses_path(status: "kept")

      expect(response.body).to include("Kept value")
      expect(response.body).not_to include("Pending value")
    end

    it "filters to dismissed" do
      sign_in admin
      create(:other_response, text: "Pending value")
      create(:other_response, :dismissed, text: "Dismissed value")

      get other_responses_path(status: "dismissed")

      expect(response.body).to include("Dismissed value")
      expect(response.body).not_to include("Pending value")
    end

    it "shows promoted responses (read-only, with the sector) under the Promoted filter" do
      sign_in admin
      sector = create(:sector, name: "Equine Therapy")
      create(:other_response, :promoted, text: "Equine therapy", promotable: sector)

      get other_responses_path(status: "promoted")

      expect(response.body).to include("Equine therapy")   # the typed value
      expect(response.body).to include("Equine Therapy")   # the sector it became
      expect(response.body).to include("Promoted")
      expect(response.body).not_to include("Create sector") # no actions on a promoted row
    end

    it "hides promoted responses from the default (reviewable) view" do
      sign_in admin
      create(:other_response, :promoted, text: "Equine therapy")

      get other_responses_path

      expect(response.body).not_to include("Equine therapy")
    end

    it "anchors each group row for chip deep-links" do
      sign_in admin
      response_record = create(:other_response, text: "Equine therapy")

      get other_responses_path

      expect(response.body).to include(%(id="#{response_record.review_anchor}"))
    end

    it "points the eyebrow back to the person when arrived from their page" do
      sign_in admin
      person = create(:person)
      create(:other_response, owner: person, text: "Equine therapy")

      get other_responses_path(return_to: "person_edit", person_id: person.id)

      expect(response.body).to include(edit_person_path(person))
    end
  end

  describe "POST /other_responses/curate (bulk)" do
    it "requires an admin" do
      create(:other_response, text: "Equine therapy")
      post curate_other_responses_path, params: { kind: "sector", normalized_text: "equine therapy", status: "dismissed" }
      expect(response).not_to have_http_status(:ok)
    end

    it "keeps every visible person in a sector group" do
      sign_in admin
      one = create(:other_response, text: "Equine therapy")
      two = create(:other_response, text: "equine therapy")

      post curate_other_responses_path,
           params: { kind: "sector", normalized_text: "equine therapy", status: "kept" }

      expect(one.reload.status).to eq("kept")
      expect(two.reload.status).to eq("kept")
    end

    it "dismisses a generic group scoped to its question" do
      sign_in admin
      generic = create(:other_response, :generic, text: "A friend")
      sector = create(:other_response, text: "A friend")

      post curate_other_responses_path,
           params: { field_identifier: "how_did_you_hear", normalized_text: "a friend", status: "dismissed" }

      expect(generic.reload.status).to eq("dismissed")
      # The identically-typed sector value on a different question is untouched.
      expect(sector.reload.status).to eq("pending")
    end

    it "revives a dismissed group when kept" do
      sign_in admin
      dismissed = create(:other_response, :dismissed, text: "Equine therapy")

      post curate_other_responses_path,
           params: { kind: "sector", normalized_text: "equine therapy", status: "kept" }

      expect(dismissed.reload.status).to eq("kept")
    end

    it "dismisses an organization-type group by kind" do
      sign_in admin
      org_response = create(:other_response, :organization_type, text: "Nonprofit collective")

      post curate_other_responses_path,
           params: { kind: "organization_type", field_identifier: "agency_type", normalized_text: "nonprofit collective", status: "dismissed" }

      expect(org_response.reload.status).to eq("dismissed")
    end

    it "rejects an unsupported status" do
      sign_in admin
      response_record = create(:other_response, text: "Equine therapy")

      post curate_other_responses_path,
           params: { kind: "sector", normalized_text: "equine therapy", status: "promoted" }

      expect(response).to redirect_to(other_responses_path)
      expect(response_record.reload.status).to eq("pending")
    end
  end

  describe "PATCH /other_responses/:id (dismiss)" do
    it "dismisses the response and returns to the person edit page" do
      sign_in admin
      response_record = create(:other_response, text: "Equine therapy")

      patch other_response_path(response_record),
            params: { other_response: { status: "dismissed" }, return_to: "person_edit" }

      expect(response).to redirect_to(edit_person_path(response_record.owner))
      expect(response_record.reload.status).to eq("dismissed")
    end
  end

  describe "POST /other_responses/promote" do
    it "requires an admin" do
      sector = create(:sector, name: "Equine Therapy")
      create(:other_response, text: "Equine therapy")
      post promote_other_responses_path, params: { kind: "sector", normalized_text: "equine therapy", sector_id: sector.id }
      expect(response).not_to have_http_status(:ok)
    end

    it "tags everyone in the group — including dismissed — and marks them promoted" do
      sign_in admin
      sector = create(:sector, name: "Equine Therapy")
      kept = create(:other_response, owner: create(:person), text: "Equine therapy")
      dismissed = create(:other_response, :dismissed, owner: create(:person), text: "Equine therapy")

      post promote_other_responses_path,
           params: { kind: "sector", normalized_text: "equine therapy", sector_id: sector.id }

      expect(kept.reload.status).to eq("promoted")
      expect(kept.owner.sectors).to include(sector)
      # Dismissed responses stay in the queue and are promoted too.
      expect(dismissed.reload.status).to eq("promoted")
      expect(dismissed.owner.sectors).to include(sector)
    end

    it "also tags the org the person registered with (derived via the response's submission)" do
      sign_in admin
      sector = create(:sector, name: "Equine Therapy")
      person = create(:person)
      event = create(:event)
      organization = create(:organization)
      registration = create(:event_registration, registrant: person, event: event)
      create(:event_registration_organization, event_registration: registration, organization: organization)
      submission = create(:form_submission, person: person, event: event)
      answer = create(:form_answer, form_submission: submission,
                      form_field: create(:form_field, field_identifier: "additional_sectors"),
                      submitted_answer: "Other: Equine therapy")
      create(:other_response, owner: person, text: "Equine therapy", source_form_answer: answer)

      post promote_other_responses_path,
           params: { kind: "sector", normalized_text: "equine therapy", sector_id: sector.id }

      expect(person.sectors).to include(sector)
      expect(organization.sectors).to include(sector)
      expect(organization.sectorable_items.find_by(sector: sector).is_primary).to be(false)
    end

    it "mints a new published sector when given a name" do
      sign_in admin
      person = create(:person)
      create(:other_response, owner: person, text: "Equine therapy")

      expect {
        post promote_other_responses_path,
             params: { kind: "sector", normalized_text: "equine therapy", new_sector_name: "Equine therapy" }
      }.to change(Sector, :count).by(1)

      sector = Sector.find_by(name: "Equine therapy")
      expect(sector.published).to be(true)
      expect(person.sectors).to include(sector)
    end

    it "does not promote a generic group" do
      sign_in admin
      generic = create(:other_response, :generic, text: "A friend")
      sector = create(:sector, name: "A Friend")

      post promote_other_responses_path,
           params: { field_identifier: "how_did_you_hear", normalized_text: "a friend", sector_id: sector.id }

      expect(generic.reload.status).to eq("pending")
      expect(generic.owner.sectors).not_to include(sector)
    end
  end
end
