require "rails_helper"

RSpec.describe "People search", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:turbo_headers) { { "Turbo-Frame" => "people_results", "Accept" => "text/html" } }

  before { sign_in admin }

  describe "GET /people (turbo frame)" do
    let!(:person_alice) { create(:person, first_name: "Alice", last_name: "Wonderland") }
    let!(:person_bob)   { create(:person, first_name: "Bob", last_name: "Builder") }

    it "returns search results successfully" do
      get people_path, headers: turbo_headers
      expect(response).to have_http_status(:ok)
    end

    it "breaks the person profile button out of the results frame" do
      get people_path, headers: turbo_headers
      expect_frame_breakout(response.body, person_path(person_alice))
    end

    it "returns all people when no filters are applied" do
      get people_path, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).to include("Bob")
    end

    it "filters by contact_info" do
      get people_path, params: { contact_info: "Alice" }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end

    it "filters by organization name" do
      org = create(:organization, name: "Unique Org")
      create(:affiliation, person: person_alice, organization: org)

      get people_path, params: { organization_name: "Unique Org" }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end

    it "filters by role" do
      create(:story, author: person_alice)

      get people_path, params: { role: "story_author" }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end

    it "filters by facilitator status" do
      create(:affiliation, person: person_alice, title: "Facilitator", end_date: nil)
      create(:affiliation, person: person_bob, title: "Facilitator", end_date: 1.year.ago)

      get people_path, params: { facilitator_status: "active" }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end

    it "filters by topic subscription" do
      topic = create(:topic_subscription_type)
      create(:topic_subscription, person: person_bob, topic_subscription_type: topic)

      get people_path, params: { topic_subscription_type_id: topic.id }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bob")
      expect(response.body).not_to include("Alice")
    end

    it "filters by staff tag" do
      tag = create(:staff_tag)
      create(:staff_tagging, staff_tag: tag, staff_taggable: person_alice)

      get people_path, params: { staff_tag_ids: tag.id }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end
  end

  describe "GET /people (full page) admin filters" do
    it "always renders the staff tag filter with a manage link, even when none are published" do
      expect(StaffTag.published).to be_empty

      get people_path
      page = Capybara.string(response.body)
      expect(page).to have_css("select[name=staff_tag_ids]")
      expect(page).to have_link("Manage staff tags", href: staff_tags_path)
    end

    it "always renders the topic subscription filter with a manage link, even when none exist" do
      expect(TopicSubscriptionType.active).to be_empty

      get people_path
      page = Capybara.string(response.body)
      expect(page).to have_css("select[name=topic_subscription_type_id]")
      expect(page).to have_link("Manage topics", href: topic_subscription_types_path)
    end
  end

  describe "GET /people?organization_id=X (full page)" do
    let!(:org) { create(:organization, name: "Scoped Org") }

    it "surfaces a chip naming the scoped organization" do
      get people_path, params: { organization_id: org.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Filtered to")
      expect(response.body).to include("Scoped Org")
    end

    it "preserves the organization_id filter when the search form is submitted" do
      get people_path, params: { organization_id: org.id }
      page = Capybara.string(response.body)
      expect(page).to have_css("input[type=hidden][name=organization_id][value='#{org.id}']", visible: :all)
    end
  end
end
