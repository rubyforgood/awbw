# spec/requests/admin/analytics_spec.rb
require "rails_helper"

RSpec.describe "/admin/analytics", type: :request do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user) }

  before do
    sign_in admin_user
  end

  describe "GET /admin/analytics" do
    context "with no time period filter" do
      it "returns successful response" do
        get "/admin/analytics"
        expect(response).to have_http_status(:success)
      end

      it "displays all-time analytics" do
        workshop = create(:workshop, :published)
        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop.id,
          resource_title: workshop.title
        }, time: 2.months.ago)

        get "/admin/analytics"

        expect(response.body).to include("analytics")
      end
    end

    context "with past_week filter" do
      it "only counts events from the past week" do
        workshop = create(:workshop, :published)

        # Event within the past week
        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop.id
        }, time: 3.days.ago)

        # Event outside the past week
        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop.id
        }, time: 2.months.ago)

        get "/admin/analytics", params: { time_period: "past_week" }

        expect(response).to have_http_status(:success)
        expect(assigns(:summary)[:workshops]).to eq(1)
      end
    end

    context "with past_month filter" do
      it "only counts events from the past month" do
        workshop = create(:workshop, :published)

        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop.id
        }, time: 2.weeks.ago)

        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop.id
        }, time: 2.months.ago)

        get "/admin/analytics", params: { time_period: "past_month" }

        expect(response).to have_http_status(:success)
        expect(assigns(:summary)[:workshops]).to eq(1)
      end
    end

    context "with past_year filter" do
      it "only counts events from the past year" do
        workshop = create(:workshop, :published)

        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop.id
        }, time: 6.months.ago)

        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop.id
        }, time: 2.years.ago)

        get "/admin/analytics", params: { time_period: "past_year" }

        expect(response).to have_http_status(:success)
        expect(assigns(:summary)[:workshops]).to eq(1)
      end
    end
  end

  describe "most viewed resources" do
    it "returns workshops ordered by view count" do
      workshop1 = create(:workshop, :published, title: "Popular Workshop")
      workshop2 = create(:workshop, :published, title: "Less Popular")

      # Create 5 views for workshop1
      5.times do
        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop1.id
        })
      end

      # Create 2 views for workshop2
      2.times do
        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop2.id
        })
      end

      get "/admin/analytics"

      expect(assigns(:most_viewed_workshops).first.id).to eq(workshop1.id)
      expect(assigns(:most_viewed_workshops).map(&:id)).to eq([ workshop1.id, workshop2.id ])
    end

    it "limits results to top 10" do
      15.times do |i|
        workshop = create(:workshop, :published)
        (15 - i).times do
          create(:ahoy_event, name: "view.workshop", properties: {
            resource_type: "Workshop",
            resource_id: workshop.id
          })
        end
      end

      get "/admin/analytics"

      expect(assigns(:most_viewed_workshops).length).to eq(10)
    end
  end

  describe "most printed resources" do
    it "returns workshops ordered by print count" do
      workshop1 = create(:workshop, :published)
      workshop2 = create(:workshop, :published)

      3.times do
        create(:ahoy_event, name: "print.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop1.id
        })
      end

      create(:ahoy_event, name: "print.workshop", properties: {
        resource_type: "Workshop",
        resource_id: workshop2.id
      })

      get "/admin/analytics"

      expect(assigns(:most_printed_workshops).first.id).to eq(workshop1.id)
    end
  end

  describe "most downloaded resources" do
    it "returns resources ordered by download count" do
      resource1 = create(:resource)
      resource2 = create(:resource)

      4.times do
        create(:ahoy_event, name: "download.resource", properties: {
          resource_type: "Resource",
          resource_id: resource1.id
        })
      end

      create(:ahoy_event, name: "download.resource", properties: {
        resource_type: "Resource",
        resource_id: resource2.id
      })

      get "/admin/analytics"

      expect(assigns(:most_downloaded_resources).first.id).to eq(resource1.id)
    end
  end

  describe "zero engagement resources" do
    it "finds resources with no views in the time period" do
      viewed_workshop = create(:workshop, :published)
      unviewed_workshop = create(:workshop, :published)

      create(:ahoy_event, name: "view.workshop", properties: {
        resource_type: "Workshop",
        resource_id: viewed_workshop.id
      })

      get "/admin/analytics"

      expect(assigns(:zero_engagement_workshops).map(&:id)).to include(unviewed_workshop.id)
      expect(assigns(:zero_engagement_workshops).map(&:id)).not_to include(viewed_workshop.id)
    end
  end

  describe "summary statistics" do
    it "calculates total view counts for each resource type" do
      workshop = create(:workshop, :published)
      resource = create(:resource)

      3.times { create(:ahoy_event, name: "view.workshop", properties: { resource_id: workshop.id }) }
      2.times { create(:ahoy_event, name: "view.resource", properties: { resource_id: resource.id }) }

      get "/admin/analytics"

      expect(assigns(:summary)[:workshops]).to eq(3)
      expect(assigns(:summary)[:resources]).to eq(2)
    end

    it "calculates print and download counts" do
      workshop = create(:workshop, :published)
      resource = create(:resource)

      2.times { create(:ahoy_event, name: "print.workshop", properties: { resource_id: workshop.id }) }
      3.times { create(:ahoy_event, name: "download.resource", properties: { resource_id: resource.id }) }

      get "/admin/analytics"

      expect(assigns(:summary)[:workshop_prints]).to eq(2)
      expect(assigns(:summary)[:resource_downloads]).to eq(3)
    end
  end

  describe "POST /admin/analytics/print" do
    it "tracks print event and increments counter" do
      workshop = create(:workshop, :published, print_count: 0)

      expect {
        post "/admin/analytics/print", params: {
          printable_type: "Workshop",
          printable_id: workshop.id
        }
      }.to change(Ahoy::Event, :count).by(1)

      expect(workshop.reload.print_count).to eq(1)
      expect(Ahoy::Event.last.name).to eq("print.workshop")
    end

    it "returns bad request for invalid printable type" do
      post "/admin/analytics/print", params: {
        printable_type: "InvalidType",
        printable_id: 1
      }

      expect(response).to have_http_status(:bad_request)
    end

    it "returns not found for non-existent resource" do
      post "/admin/analytics/print", params: {
        printable_type: "Workshop",
        printable_id: 999999
      }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "access control" do
    context "when user is not an admin" do
      before do
        sign_out admin_user
        sign_in regular_user
      end

      it "denies access to analytics page" do
        get "/admin/analytics"
        expect(response).to_not have_http_status(:success)
      end
    end
  end
end
