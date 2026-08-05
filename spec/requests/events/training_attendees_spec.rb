require "rails_helper"

RSpec.describe "Events training attendees", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  let!(:recent_training) { create(:event, title: "TAC 261", abbreviation: "TAC261", facilitator_training: true, start_date: Date.new(2026, 5, 1)) }
  let!(:older_training) { create(:event, title: "TAC 200", facilitator_training: true, start_date: Date.new(2024, 5, 1)) }
  let!(:webinar) { create(:event, title: "Open webinar", facilitator_training: false, start_date: Date.new(2025, 5, 1)) }

  let!(:attendee) { create(:person, first_name: "Ada", last_name: "Lovelace") }
  let!(:non_training_attendee) { create(:person, first_name: "Grace", last_name: "Hopper") }
  let!(:no_show) { create(:person, first_name: "Alan", last_name: "Turing") }

  let!(:attendee_registration) { create(:event_registration, event: recent_training, registrant: attendee, status: "attended") }

  before do
    create(:event_registration, event: webinar, registrant: non_training_attendee, status: "attended")
    create(:event_registration, event: recent_training, registrant: no_show, status: "no_show")
  end

  let(:frame_headers) { { "Turbo-Frame" => "training_attendees_results" } }

  describe "GET /events/training_attendees" do
    context "as non-admin" do
      it "redirects" do
        sign_in user
        get training_attendees_events_url
        expect(response).to redirect_to(root_path)
      end
    end

    context "as admin" do
      before { sign_in admin }

      it "renders the index shell" do
        get training_attendees_events_url
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Training attendees")
      end

      it "carries the participation origin back through the eyebrow" do
        get training_attendees_events_url(return_to: "participation")
        expect(response.body).to include("← Participation")
      end

      context "the results frame" do
        it "lists people who attended a training and links each to its registration" do
          get training_attendees_events_url, headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).to include("TAC261")
          expect(response.body).to include(edit_event_registration_path(attendee_registration))
        end

        it "excludes non-training attendees and no-shows" do
          get training_attendees_events_url, headers: frame_headers
          expect(response.body).not_to include("Grace Hopper")
          expect(response.body).not_to include("Alan Turing")
        end

        it "filters by training" do
          create(:event_registration, event: older_training, registrant: create(:person, first_name: "Katherine", last_name: "Johnson"), status: "attended")

          get training_attendees_events_url(event_id: recent_training.id), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Katherine Johnson")
        end

        it "filters by year" do
          create(:event_registration, event: older_training, registrant: create(:person, first_name: "Katherine", last_name: "Johnson"), status: "attended")

          get training_attendees_events_url(event_year: 2024), headers: frame_headers
          expect(response.body).to include("Katherine Johnson")
          expect(response.body).not_to include("Ada Lovelace")
        end

        it "filters by name search" do
          create(:event_registration, event: recent_training, registrant: create(:person, first_name: "Katherine", last_name: "Johnson"), status: "attended")

          get training_attendees_events_url(contact_info: "Lovelace"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Katherine Johnson")
        end
      end
    end
  end
end
