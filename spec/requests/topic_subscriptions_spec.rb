require "rails_helper"

RSpec.describe "TopicSubscriptions", type: :request do
  let(:admin) { create(:user, :with_person, super_user: true) }

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
      create(:topic_subscription, person: person, topic: "facilitator_trainings", interested_event: nil)

      get topic_subscriptions_path, headers: { "Turbo-Frame" => "topic_subscriptions_results" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dana Rivers")
      # The registrations column surfaces only facilitator-training events.
      expect(response.body).to include("TAC263 Spring Training")
      expect(response.body).not_to include("Community Open House")
    end

    it "filters by topic via the frame request" do
      create(:topic_subscription, person: create(:person, first_name: "Tara", last_name: "Trainings"), topic: "facilitator_trainings")
      create(:topic_subscription, :news, person: create(:person, first_name: "Nora", last_name: "News"))

      get topic_subscriptions_path(topic: "news"), headers: { "Turbo-Frame" => "topic_subscriptions_results" }

      expect(response.body).to include("Nora News")
      expect(response.body).not_to include("Tara Trainings")
    end
  end

  describe "GET new and edit" do
    it "renders the new form" do
      get new_topic_subscription_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("New subscription")
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
          topic_subscription: { person_id: person.id, topic: "facilitator_trainings", source: "admin" }
        }
      }.to change(TopicSubscription, :count).by(1)

      subscription = TopicSubscription.last
      expect(subscription.person).to eq(person)
      expect(subscription.created_by).to eq(admin)
      expect(subscription).to be_general
      expect(subscription).to be_active
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
