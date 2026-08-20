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
      create(:grant, funder: person)
      create(:form_submission, person: person)
      create(:payment, person: person)
      create(:notification, recipient_email: person.preferred_email)
      create(:topic_subscription, person: person)

      get edit_person_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Associated records")
      # Split into two clusters
      expect(response.body).to include("Administrative")
      expect(response.body).to include("Contributed content")
      # Subscriptions card (general cluster), filtered to this person
      expect(response.body).to include("Subscriptions")
      expect(response.body).to include(topic_subscriptions_path(person_id: person.id))
      expect(response.body).to include(event_registrations_path(registrant_id: person.id))
      expect(response.body).to include(workshop_logs_person_path(person))
      expect(response.body).to include(stories_path(author_id: person.id))
      expect(response.body).to include(workshops_path(author_id: person.id))
      expect(response.body).to include(workshop_variations_path(author_id: person.id))
      expect(response.body).to include(community_news_index_path(author_id: person.id))
      expect(response.body).to include(resources_path(author_id: person.id))
      expect(response.body).to include(scholarships_path(recipient_id: person.id))
      expect(response.body).to include(CGI.escapeHTML(grants_path(funder_id: person.id, funder_type: "Person")))
      expect(response.body).to include(form_submissions_path(person_id: person.id))
      expect(response.body).to include(payments_path(person_id: person.id))
      expect(response.body).to include(notifications_path(email: person.preferred_email))

      # Custom card labels
      expect(response.body).to include("Grants (as funder)")
      expect(response.body).to include("Communications (universal)")
    end

    it "scopes the idea cards to the person, not their user account" do
      person = create(:person)
      create(:story_idea, created_by: person.user)
      create(:story_idea, created_by: create(:user))

      get edit_person_path(person)

      expect(response.body).to include(story_ideas_path(created_by_person_id: person.id))
      expect(response.body).to include(workshop_ideas_path(created_by_person_id: person.id))
      expect(response.body).to include(workshop_variation_ideas_path(created_by_person_id: person.id))
    end

    it "keeps the idea cards filtered when the person has no user account" do
      person = create(:person, user: nil)
      create(:story_idea)

      get edit_person_path(person)

      # A person with no user authored nothing — the card must not fall through
      # to the unfiltered index of everyone's ideas.
      expect(response.body).to include(story_ideas_path(created_by_person_id: person.id))
      expect(response.body).not_to include(%(href="#{story_ideas_path}"))
      expect(response.body).not_to include(%(href="#{workshop_ideas_path}"))
      expect(response.body).not_to include(%(href="#{workshop_variation_ideas_path}"))
    end
  end
end
