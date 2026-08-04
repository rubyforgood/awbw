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
      # Row action is a plain link (no JS) to the subscription's edit page.
      expect(response.body).to include(edit_topic_subscription_path(TopicSubscription.last, return_to: "index"))
    end

    it "filters by person (from the person page's associated records)" do
      mine = create(:person, first_name: "Mine", last_name: "Person")
      create(:topic_subscription, person: mine, topic_subscription_type: trainings)
      create(:topic_subscription, person: create(:person, first_name: "Other", last_name: "Person"), topic_subscription_type: trainings)

      get topic_subscriptions_path(person_id: mine.id), headers: { "Turbo-Frame" => "topic_subscriptions_results" }

      expect(response.body).to include("Mine Person")
      expect(response.body).not_to include("Other Person")
    end

    it "prefills the filter form's person picker so the scope survives a filter change" do
      person = create(:person, first_name: "Mine", last_name: "Person")
      create(:topic_subscription, person: person, topic_subscription_type: trainings)

      get topic_subscriptions_path(person_id: person.id)

      # The picker carries person_id on every subsequent filter submit.
      expect(response.body).to include('name="person_id"')
      expect(response.body).to include("Mine Person")
    end

    it "filters by topic via the frame request" do
      news = create(:topic_subscription_type, :news)
      create(:topic_subscription, person: create(:person, first_name: "Tara", last_name: "Trainings"), topic_subscription_type: trainings)
      create(:topic_subscription, person: create(:person, first_name: "Nora", last_name: "News"), topic_subscription_type: news)

      get topic_subscriptions_path(topic_subscription_type_id: news.id), headers: { "Turbo-Frame" => "topic_subscriptions_results" }

      expect(response.body).to include("Nora News")
      expect(response.body).not_to include("Tara Trainings")
    end

    it "eager loads each subscriber's user so the row count doesn't drive the query count" do
      5.times { create(:topic_subscription, person: create(:person), topic_subscription_type: trainings) }

      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        queries << payload[:sql] if payload[:sql]&.include?("`users`") && payload[:name] != "SCHEMA"
      end
      get topic_subscriptions_path, headers: { "Turbo-Frame" => "topic_subscriptions_results" }
      ActiveSupport::Notifications.unsubscribe(subscriber)

      # One preload for the five rows' users, plus Devise's current_user lookup.
      expect(queries.size).to be <= 2
    end
  end

  describe "GET /topic_subscriptions/email_addresses" do
    it "lists the unique subscriber emails comma-separated, honoring filters" do
      news = create(:topic_subscription_type, :news)
      tara = create(:person, first_name: "Tara", last_name: "Trainings", email: "tara@example.com", user: nil)
      nora = create(:person, first_name: "Nora", last_name: "News", email: "nora@example.com", user: nil)
      create(:topic_subscription, person: tara, topic_subscription_type: trainings)
      create(:topic_subscription, person: nora, topic_subscription_type: news)

      get email_addresses_topic_subscriptions_path(topic_subscription_type_id: trainings.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("tara@example.com")
      expect(response.body).not_to include("nora@example.com")
    end

    it "falls back to the person's preferred email when the email column is blank" do
      on_user = create(:person, email: nil, user: create(:user, email: "dana@example.com"))
      on_email_2 = create(:person, email: nil, email_2: "rio@example.com", user: nil)
      create(:topic_subscription, person: on_user, topic_subscription_type: trainings)
      create(:topic_subscription, person: on_email_2, topic_subscription_type: trainings)

      get email_addresses_topic_subscriptions_path(topic_subscription_type_id: trainings.id)

      expect(response.body).to include("dana@example.com")
      expect(response.body).to include("rio@example.com")
    end

    it "omits people who unsubscribed, even when the index filter shows every status" do
      still_in = create(:person, email: "still@example.com", user: nil)
      opted_out = create(:person, email: "optedout@example.com", user: nil)
      create(:topic_subscription, person: still_in, topic_subscription_type: trainings)
      create(:topic_subscription, :unsubscribed, person: opted_out, topic_subscription_type: trainings)

      get email_addresses_topic_subscriptions_path

      expect(response.body).to include("still@example.com")
      expect(response.body).not_to include("optedout@example.com")
    end

    it "omits people who unsubscribed even when explicitly filtered to unsubscribed" do
      opted_out = create(:person, email: "optedout@example.com", user: nil)
      create(:topic_subscription, :unsubscribed, person: opted_out, topic_subscription_type: trainings)

      get email_addresses_topic_subscriptions_path(status: "unsubscribed")

      expect(response.body).not_to include("optedout@example.com")
    end

    it "adds back the unsubscribed when the include toggle is on" do
      opted_out = create(:person, email: "optedout@example.com", user: nil)
      create(:topic_subscription, :unsubscribed, person: opted_out, topic_subscription_type: trainings)

      get email_addresses_topic_subscriptions_path(include_unsubscribed: "1")

      expect(response.body).to include("optedout@example.com")
    end

    it "omits people already registered for the event their subscription names" do
      training = create(:event, facilitator_training: true)
      enrolled = create(:person, email: "enrolled@example.com", user: nil)
      waiting = create(:person, email: "waiting@example.com", user: nil)
      create(:event_registration, registrant: enrolled, event: training)
      create(:topic_subscription, person: enrolled, topic_subscription_type: trainings, interested_event: training)
      create(:topic_subscription, person: waiting, topic_subscription_type: trainings, interested_event: training)

      get email_addresses_topic_subscriptions_path

      expect(response.body).to include("waiting@example.com")
      expect(response.body).not_to include("enrolled@example.com")
    end

    it "adds back the already-registered when the include toggle is on" do
      training = create(:event, facilitator_training: true)
      enrolled = create(:person, email: "enrolled@example.com", user: nil)
      create(:event_registration, registrant: enrolled, event: training)
      create(:topic_subscription, person: enrolled, topic_subscription_type: trainings, interested_event: training)

      get email_addresses_topic_subscriptions_path(include_registered: "1")

      expect(response.body).to include("enrolled@example.com")
    end

    it "keeps a general subscriber who is registered for some unrelated event" do
      other_event = create(:event, facilitator_training: true)
      person = create(:person, email: "general@example.com", user: nil)
      create(:event_registration, registrant: person, event: other_event)
      create(:topic_subscription, person: person, topic_subscription_type: trainings, interested_event: nil)

      get email_addresses_topic_subscriptions_path

      expect(response.body).to include("general@example.com")
    end

    it "shows grey chips describing the applied index filters" do
      get email_addresses_topic_subscriptions_path(topic_subscription_type_id: trainings.id, status: "active", q: "smith")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Topic:")
      expect(response.body).to include(trainings.name)
      expect(response.body).to include("Status:")
      expect(response.body).to include("Active")
      expect(response.body).to include("Search:")
      expect(response.body).to include("smith")
    end

    it "shows no filter chips when the list is unfiltered" do
      get email_addresses_topic_subscriptions_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(">Filters<")
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
      # Event + topic shown as read-only display values (edit-toggle), and the eyebrow returns to the event.
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

    it "renders the edit form with unsubscribe and remove actions" do
      subscription = create(:topic_subscription)
      get edit_topic_subscription_path(subscription)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit subscription")
      expect(response.body).to include("Unsubscribe")
      expect(response.body).to include("Remove")
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
