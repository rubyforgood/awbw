require "rails_helper"

RSpec.describe "TopicSubscriptionTypes", type: :request do
  let(:admin) { create(:user, :with_person, super_user: true) }

  before { sign_in admin }

  describe "GET /topic_subscription_types" do
    it "lists topics with their subscription counts" do
      type = create(:topic_subscription_type, name: "Facilitator trainings")
      create(:topic_subscription, topic_subscription_type: type)

      get topic_subscription_types_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Facilitator trainings")
      expect(response.body).to include("facilitator_trainings")
    end
  end

  describe "POST /topic_subscription_types" do
    it "creates a topic and derives its key" do
      expect {
        post topic_subscription_types_path, params: {
          topic_subscription_type: { name: "Volunteering", description: "Volunteer opportunities" }
        }
      }.to change(TopicSubscriptionType, :count).by(1)

      type = TopicSubscriptionType.last
      expect(type.name).to eq("Volunteering")
      expect(type.key).to eq("volunteering")
      expect(type.created_by).to eq(admin)
    end

    it "rejects a blank name" do
      post topic_subscription_types_path, params: { topic_subscription_type: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH archive / unarchive" do
    it "archives and restores a topic" do
      type = create(:topic_subscription_type)

      patch archive_topic_subscription_type_path(type)
      expect(type.reload).to be_archived

      patch unarchive_topic_subscription_type_path(type)
      expect(type.reload).not_to be_archived
    end
  end

  describe "DELETE /topic_subscription_types/:id" do
    it "deletes an unused topic" do
      type = create(:topic_subscription_type)

      expect {
        delete topic_subscription_type_path(type)
      }.to change(TopicSubscriptionType, :count).by(-1)
    end

    it "refuses to delete a topic that has subscriptions" do
      type = create(:topic_subscription_type)
      create(:topic_subscription, topic_subscription_type: type)

      expect {
        delete topic_subscription_type_path(type)
      }.not_to change(TopicSubscriptionType, :count)
      expect(response).to redirect_to(topic_subscription_types_path)
    end
  end

  it "denies non-admins" do
    sign_out admin
    sign_in create(:user, :with_person)

    get topic_subscription_types_path

    expect(response).not_to have_http_status(:success)
  end
end
