require "rails_helper"

RSpec.describe "Person names shown to admins", type: :request do
  let!(:person) do
    create(:person, first_name: "Dana", last_name: "Rivers", display_name_preference: "first_name_last_initial").tap do |p|
      create(:affiliation, person: p, title: "Facilitator", start_date: 1.year.ago, inactive: false)
    end
  end
  let(:people_frame) { { "Turbo-Frame" => "people_results" } }

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it "shows the full name on the people index" do
      get people_path, headers: people_frame

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dana Rivers")
    end

    it "shows the full name on the profile" do
      get person_path(person)

      expect(response.body).to include("Dana Rivers")
    end

    it "shows the full name on the subscriptions list" do
      create(:topic_subscription, person:, topic_subscription_type: create(:topic_subscription_type, :facilitator_trainings))

      get topic_subscriptions_path, headers: { "Turbo-Frame" => "topic_subscriptions_results" }

      expect(response.body).to include("Dana Rivers")
    end
  end

  context "as a non-admin" do
    before { sign_in create(:user, :with_person) }

    it "shows the preferred name on the people index" do
      get people_path, headers: people_frame

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dana R.")
      expect(response.body).not_to include("Dana Rivers")
    end
  end
end
