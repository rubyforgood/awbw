require "rails_helper"

RSpec.describe "Person edit associated records", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /people/:id/edit" do
    it "links to the person's filtered registrations, workshop logs, scholarships, and notifications" do
      person = create(:person)
      create(:event_registration, registrant: person)
      create(:workshop_log, created_by: person.user)
      create(:scholarship, recipient: person)
      create(:notification, recipient_email: person.preferred_email)

      get edit_person_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Associated records")
      expect(response.body).to include(event_registrations_path(registrant_id: person.id))
      expect(response.body).to include(workshop_logs_person_path(person))
      expect(response.body).to include(scholarships_path(recipient_id: person.id))
      expect(response.body).to include(notifications_path(email: person.preferred_email))
    end
  end
end
