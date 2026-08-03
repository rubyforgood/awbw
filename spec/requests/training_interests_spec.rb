require "rails_helper"

RSpec.describe "TrainingInterests", type: :request do
  let(:admin) { create(:user, :with_person, super_user: true) }

  before { sign_in admin }

  describe "GET /training_interests" do
    it "renders the index shell for a full-page request" do
      get training_interests_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Training interest")
    end

    it "lists interests and shows the person's facilitator-training registrations" do
      person = create(:person, first_name: "Dana", last_name: "Rivers")
      training = create(:event, title: "TAC263 Spring Training", facilitator_training: true)
      other_event = create(:event, title: "Community Open House", facilitator_training: false)
      create(:event_registration, registrant: person, event: training)
      create(:event_registration, registrant: person, event: other_event)
      create(:training_interest, person: person, event: nil)

      get training_interests_path, headers: { "Turbo-Frame" => "training_interests_results" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dana Rivers")
      # The Registrations column surfaces only facilitator-training events.
      expect(response.body).to include("TAC263 Spring Training")
      expect(response.body).not_to include("Community Open House")
    end

    it "filters to general interests via the frame request" do
      general = create(:training_interest, person: create(:person, first_name: "Gen", last_name: "Eral"), event: nil)
      specific = create(:training_interest, person: create(:person, first_name: "Spec", last_name: "Ific"),
        event: create(:event, title: "Specific TAC"))

      get training_interests_path(status: "general"), headers: { "Turbo-Frame" => "training_interests_results" }

      expect(response.body).to include("Gen Eral")
      expect(response.body).not_to include("Spec Ific")
    end
  end

  describe "GET /training_interests/new and edit" do
    it "renders the new form" do
      get new_training_interest_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("New training interest")
    end

    it "renders the edit form" do
      interest = create(:training_interest)
      get edit_training_interest_path(interest)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit training interest")
    end
  end

  describe "POST /training_interests" do
    it "records a new interest" do
      person = create(:person)

      expect {
        post training_interests_path, params: {
          training_interest: { person_id: person.id, status: "open", source: "admin" }
        }
      }.to change(TrainingInterest, :count).by(1)

      interest = TrainingInterest.last
      expect(interest.person).to eq(person)
      expect(interest.created_by).to eq(admin)
      expect(interest).to be_general
    end
  end

  describe "PATCH /training_interests/:id" do
    it "converts an interest" do
      interest = create(:training_interest)

      patch training_interest_path(interest), params: { training_interest: { status: "converted" } }

      expect(interest.reload.status).to eq("converted")
    end
  end

  describe "DELETE /training_interests/:id" do
    it "removes the interest" do
      interest = create(:training_interest)

      expect {
        delete training_interest_path(interest)
      }.to change(TrainingInterest, :count).by(-1)
    end
  end

  it "denies non-admins" do
    sign_out admin
    sign_in create(:user, :with_person)

    get training_interests_path

    expect(response).not_to have_http_status(:success)
  end
end
