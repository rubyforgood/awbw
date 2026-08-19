require "rails_helper"

RSpec.describe "People#affiliation_history", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: "Sunrise Center") }

  describe "GET /people/:id/affiliation_history" do
    context "as an admin" do
      before { sign_in admin }

      it "renders the merged affiliation history" do
        create(:affiliation, person: person, organization: organization,
                             title: "Facilitator", start_date: 1.year.ago.to_date)
        event = create(:event, facilitator_training: true, title: "Intro Training",
                               start_date: 2.years.ago, end_date: 2.years.ago + 1.day,
                               registration_close_date: 2.years.ago - 1.day)
        registration = create(:event_registration, event: event, registrant: person, status: "attended")
        create(:event_registration_organization, event_registration: registration, organization: organization)

        get affiliation_history_person_path(person)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Affiliation history")
        expect(response.body).to include("Sunrise Center")
        expect(response.body).to include("Intro Training")
      end

      it "shows an empty state when there is nothing on record" do
        get affiliation_history_person_path(person)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No affiliations, facilitator trainings, or membership periods")
      end
    end

    context "as a non-admin" do
      it "is forbidden" do
        sign_in create(:user)

        get affiliation_history_person_path(person)

        expect(response).not_to have_http_status(:ok)
      end
    end
  end
end
