require "rails_helper"

RSpec.describe "TopicSubscriptions", type: :request do
  let(:admin) { create(:user, :with_person, super_user: true) }
  let!(:trainings) { create(:topic_subscription_type, :facilitator_trainings) }

  before { sign_in admin }

  describe "GET /topic_subscriptions" do
    it "renders the index shell for a full-page request" do
      get topic_subscriptions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Subscriptions")
    end

    it "lists subscriptions and shows the person's facilitator-training registrations" do
      person = create(:person, first_name: "Dana", last_name: "Rivers")
      training = create(:event, title: "TAC263 Spring Training", facilitator_training: true)
      other_event = create(:event, title: "Community Open House", facilitator_training: false)
      create(:event_registration, registrant: person, event: training)
      create(:event_registration, registrant: person, event: other_event)
      create(:topic_subscription, person: person, topic_subscription_type: trainings, interested_event: nil)

      get topic_subscriptions_path, headers: { "Turbo-Frame" => "topic_subscriptions_results" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dana Rivers")
      # The registrations column surfaces only facilitator-training events.
      expect(response.body).to include("TAC263 Spring Training")
      expect(response.body).not_to include("Community Open House")
    end

    it "filters by person (from the person page's associated records)" do
      mine = create(:person, first_name: "Mine", last_name: "Person")
      create(:topic_subscription, person: mine, topic_subscription_type: trainings)
      create(:topic_subscription, person: create(:person, first_name: "Other", last_name: "Person"), topic_subscription_type: trainings)

      get topic_subscriptions_path(person_id: mine.id), headers: { "Turbo-Frame" => "topic_subscriptions_results" }

      expect(response.body).to include("Mine Person")
      expect(response.body).not_to include("Other Person")
    end

    it "filters by topic via the frame request" do
      news = create(:topic_subscription_type, :news)
      create(:topic_subscription, person: create(:person, first_name: "Tara", last_name: "Trainings"), topic_subscription_type: trainings)
      create(:topic_subscription, person: create(:person, first_name: "Nora", last_name: "News"), topic_subscription_type: news)

      get topic_subscriptions_path(topic_subscription_type_id: news.id), headers: { "Turbo-Frame" => "topic_subscriptions_results" }

      expect(response.body).to include("Nora News")
      expect(response.body).not_to include("Tara Trainings")
    end
  end

  describe "GET /topic_subscriptions/email_addresses" do
    it "lists the unique subscriber emails comma-separated, honoring filters" do
      news = create(:topic_subscription_type, :news)
      tara = create(:person, first_name: "Tara", last_name: "Trainings", email: "tara@example.com")
      nora = create(:person, first_name: "Nora", last_name: "News", email: "nora@example.com")
      create(:topic_subscription, person: tara, topic_subscription_type: trainings)
      create(:topic_subscription, person: nora, topic_subscription_type: news)

      get email_addresses_topic_subscriptions_path(topic_subscription_type_id: trainings.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("tara@example.com")
      expect(response.body).not_to include("nora@example.com")
    end
  end

  describe "GET new and edit" do
    it "renders the new form" do
      get new_topic_subscription_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("New subscription")
    end

    it "prefills the event and topic when opened from an event's Forms menu" do
      event = create(:event, title: "TAC263 Spring Training", facilitator_training: true)

      get new_topic_subscription_path(
        interested_event_id: event.id, topic_key: "facilitator_trainings", event_id: event.id, return_to: "dashboard"
      )

      expect(response).to have_http_status(:success)
      # Event + topic shown as flip-field display values, and the eyebrow returns to the event.
      expect(response.body).to include("TAC263 Spring Training")
      expect(response.body).to include("Facilitator trainings")
      expect(response.body).to include("← Dashboard")
      expect(response.body).to include(dashboard_event_path(event))
    end

    it "prefills the person and returns to their edit page when opened from a person" do
      person = create(:person, first_name: "Umberto", last_name: "User")

      get new_topic_subscription_path(person_id: person.id, return_to: "person")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Umberto User")
      expect(response.body).to include("← Umberto User")
      expect(response.body).to include(edit_person_path(person))
    end

    it "renders the edit form" do
      subscription = create(:topic_subscription)
      get edit_topic_subscription_path(subscription)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit subscription")
    end
  end

  describe "POST /topic_subscriptions" do
    it "adds a subscription" do
      person = create(:person)

      expect {
        post topic_subscriptions_path, params: {
          topic_subscription: { person_id: person.id, topic_subscription_type_id: trainings.id, source: "admin" }
        }
      }.to change(TopicSubscription, :count).by(1)

      subscription = TopicSubscription.last
      expect(subscription.person).to eq(person)
      expect(subscription.created_by).to eq(admin)
      expect(subscription).to be_general
      expect(subscription).to be_active
    end

    it "returns to the originating event after creating from its Forms menu" do
      person = create(:person)
      event = create(:event, facilitator_training: true)

      post topic_subscriptions_path, params: {
        return_to: "dashboard", event_id: event.id,
        topic_subscription: { person_id: person.id, topic_subscription_type_id: trainings.id, interested_event_id: event.id }
      }

      expect(response).to redirect_to(dashboard_event_path(event))
      expect(TopicSubscription.last.interested_event).to eq(event)
    end
  end

  describe "PATCH unsubscribe / resubscribe" do
    it "unsubscribes and resubscribes" do
      subscription = create(:topic_subscription)

      patch unsubscribe_topic_subscription_path(subscription)
      expect(subscription.reload).not_to be_active

      patch resubscribe_topic_subscription_path(subscription)
      expect(subscription.reload).to be_active
    end
  end

  describe "DELETE /topic_subscriptions/:id" do
    it "removes the subscription" do
      subscription = create(:topic_subscription)

      expect {
        delete topic_subscription_path(subscription)
      }.to change(TopicSubscription, :count).by(-1)
    end
  end

  it "denies non-admins" do
    sign_out admin
    sign_in create(:user, :with_person)

    get topic_subscriptions_path

    expect(response).not_to have_http_status(:success)
  end
end
