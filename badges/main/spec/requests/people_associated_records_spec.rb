require "rails_helper"

RSpec.describe "Person edit associated records", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /people/:id/edit" do
    it "links to the person's filtered registrations, workshop logs, scholarships, grants, form submissions, payments, and notifications" do
      person = create(:person)
      create(:event_registration, registrant: person)
      create(:workshop_log, created_by: person.user)
      create(:scholarship, recipient: person)
      create(:grant, donor: person)
      create(:form_submission, person: person)
      create(:payment, person: person)
      create(:notification, recipient_email: person.preferred_email)

      get edit_person_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Associated records")
      expect(response.body).to include(event_registrations_path(registrant_id: person.id))
      expect(response.body).to include(workshop_logs_person_path(person))
      expect(response.body).to include(stories_path(author_id: person.id))
      expect(response.body).to include(workshops_path(author_id: person.id))
      expect(response.body).to include(workshop_variations_path(author_id: person.id))
      expect(response.body).to include(community_news_index_path(author_id: person.id))
      expect(response.body).to include(resources_path(author_id: person.id))
      expect(response.body).to include(scholarships_path(recipient_id: person.id))
      expect(response.body).to include(CGI.escapeHTML(grants_path(donor_id: person.id, donor_type: "Person")))
      expect(response.body).to include(form_submissions_path(person_id: person.id))
      expect(response.body).to include(payments_path(person_id: person.id))
      expect(response.body).to include(notifications_path(email: person.preferred_email))

      # Custom card labels
      expect(response.body).to include("Grants (as donor)")
      expect(response.body).to include("Communications (universal)")
    end
  end
end
