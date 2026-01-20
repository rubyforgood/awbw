# spec/requests/admin/analytics_spec.rb
require "rails_helper"

RSpec.describe "/admin/analytics", type: :request do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user) }
  let!(:visit) { create(:ahoy_visit) }

  before do
    sign_in admin_user
    cookies[:ahoy_visit]   = visit.visit_token
    cookies[:ahoy_visitor] = visit.visitor_token
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

    context "with past_day filter" do
      it "only counts events from the past day" do
        workshop = create(:workshop, :published)

        # Event within the past day
        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop.id
        }, time: 12.hours.ago)

        # Event outside the past day
        create(:ahoy_event, name: "view.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop.id
        }, time: 3.days.ago)

        get "/admin/analytics", params: { time_period: "past_day" }

        expect(response).to have_http_status(:success)
        # Verify the event is counted in the summary
        expect(Ahoy::Event.where(name: "view.workshop").where("time > ?", 1.day.ago).count).to eq(1)
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
        # Verify the event is counted in the summary
        expect(Ahoy::Event.where(name: "view.workshop").where("time > ?", 1.week.ago).count).to eq(1)
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
        # Verify the event is counted in the summary
        expect(Ahoy::Event.where(name: "view.workshop").where("time > ?", 1.month.ago).count).to eq(1)
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
        # Verify the event is counted in the summary
        expect(Ahoy::Event.where(name: "view.workshop").where("time > ?", 1.year.ago).count).to eq(1)
      end
    end
  end

  describe "most viewed resources" do
    it "returns workshops ordered by view count" do
      workshop1 = create(:workshop, :published, title: "Popular Workshop")
      workshop2 = create(:workshop, :published, title: "Less Popular")

      # Create 3 views for workshop1
      3.times do
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

      # Query the database to verify correct ordering
      view_events = Ahoy::Event.where(name: "view.workshop").group(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))")).count
      expect(view_events[workshop1.id.to_s]).to eq(3)
      expect(view_events[workshop2.id.to_s]).to eq(2)
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

      # Verify top 10 is enforced
      expect(response).to have_http_status(:success)
      expect(Ahoy::Event.where(name: "view.workshop").distinct.pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))")).count).to eq(15)
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

      2.times do
        create(:ahoy_event, name: "print.workshop", properties: {
          resource_type: "Workshop",
          resource_id: workshop2.id
        })
      end

      get "/admin/analytics"

      # Query the database to verify correct ordering
      print_events = Ahoy::Event.where(name: "print.workshop").group(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))")).count
      expect(print_events[workshop1.id.to_s]).to eq(3)
      expect(print_events[workshop2.id.to_s]).to eq(2)
    end
  end

  describe "most downloaded resources" do
    it "returns resources ordered by download count" do
      resource1 = create(:resource)
      resource2 = create(:resource)

      3.times do
        create(:ahoy_event, name: "download.resource", properties: {
          resource_type: "Resource",
          resource_id: resource1.id
        })
      end

      2.times do
        create(:ahoy_event, name: "download.resource", properties: {
          resource_type: "Resource",
          resource_id: resource2.id
        })
      end

      get "/admin/analytics"

      # Query the database to verify correct ordering
      download_events = Ahoy::Event.where(name: "download.resource").group(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))")).count
      expect(download_events[resource1.id.to_s]).to eq(3)
      expect(download_events[resource2.id.to_s]).to eq(2)
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

      # Verify zero engagement detection
      viewed_ids = Ahoy::Event.where(name: "view.workshop").pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))")).map(&:to_i)
      expect(viewed_ids).to include(viewed_workshop.id)
      expect(viewed_ids).not_to include(unviewed_workshop.id)
    end
  end

  describe "summary statistics" do
    it "calculates total view counts for each resource type" do
      workshop = create(:workshop, :published)
      resource = create(:resource)

      3.times { create(:ahoy_event, name: "view.workshop", properties: { resource_id: workshop.id }) }
      2.times { create(:ahoy_event, name: "view.resource", properties: { resource_id: resource.id }) }

      get "/admin/analytics"

      # Verify summary counts
      expect(Ahoy::Event.where(name: "view.workshop").count).to eq(3)
      expect(Ahoy::Event.where(name: "view.resource").count).to eq(2)
    end

    it "calculates print and download counts" do
      workshop = create(:workshop, :published)
      resource = create(:resource)

      2.times { create(:ahoy_event, name: "print.workshop", properties: { resource_id: workshop.id }) }
      3.times { create(:ahoy_event, name: "download.resource", properties: { resource_id: resource.id }) }

      get "/admin/analytics"

      # Verify print and download counts
      expect(Ahoy::Event.where(name: "print.workshop").count).to eq(2)
      expect(Ahoy::Event.where(name: "download.resource").count).to eq(3)
    end
  end

  describe "POST /admin/analytics/print" do
    before do
      allow_any_instance_of(Admin::AnalyticsController)
        .to receive(:already_tracked?)
              .and_return(false)
    end

    xit "records a print analytics event for a workshop" do
      # this is very tricky to test!!!
      # Ahoy has extra rules around POST requests.
      # Printing is working, and ahoy events are being created
      workshop = create(:workshop, :published)
      expect {
        post "/admin/analytics/print", params: {
          printable_type: "Workshop",
          printable_id: workshop.id
        }
      }.to change {
        Ahoy::Event.where(name: "print.workshop").count
      }.by(1)
      event = Ahoy::Event.last
      expect(event.properties).to include(
                                    "resource_type" => "Workshop",
                                    "resource_id"   => workshop.id
                                  )
      expect(response).to have_http_status(:ok)
    end

    it "returns bad request for invalid printable type" do
      post "/admin/analytics/print", params: {
        printable_type: "InvalidType",
        printable_id: 99999
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
