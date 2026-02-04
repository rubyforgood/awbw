require 'rails_helper'

RSpec.describe "/events", type: :request do
  let(:valid_attributes) {
    {
      "title": "sample title",
      "description": "sample description",
      "start_date": 1.day.from_now,
      "end_date": 2.days.from_now,
      "registration_close_date": 3.days.ago,
      "publicly_visible": true
    }
  }

  let(:invalid_attributes) {
    {
      "title": "",
      "description": "",
      "start_date": "",
      "end_date": "",
      "registration_close_date": ""
    }
  }
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:event) { Event.create!(valid_attributes) }

  describe "GET /index" do
    it "renders a successful response" do
      sign_in user
      get events_url
      # puts "=====Status: #{response.status}"
      # puts "Error snippet: #{response.body.scan(/<pre.*?>(.*?)<\/pre>/m)}"
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      sign_in user

      allow_any_instance_of(ApplicationController).
        to receive(:current_user).and_return(user)
      get event_url(event)

      expect(response).to be_successful
    end

    context "when user time_zone is set" do
      # 19:00 UTC = 12:00 noon PT = 15:00 (3 pm) ET (June 15, 2025 with DST)
      let(:utc_start) { Time.utc(2025, 6, 15, 19, 0, 0) }
      let(:utc_end)   { Time.utc(2025, 6, 15, 20, 0, 0) }
      let!(:event_with_fixed_times) do
        create(:event,
          start_date: utc_start,
          end_date: utc_end,
          title: "Timezone test event")
      end

      it "displays start time in Pacific (PT) for user with time_zone PT" do
        user_pt = create(:user)
        sign_in user_pt
        get event_url(event_with_fixed_times)

        expect(response).to be_successful
        # 19:00 UTC = 12:00 noon PT
        expect(response.body).to include("Sun, Jun 15 @ 12 - 1 pm")
      end

      it "displays start time in Eastern for user with time_zone America/New_York" do
        user_et = create(:user, time_zone: "Eastern Time (US & Canada)")
        sign_in user_et
        get event_url(event_with_fixed_times)

        expect(response).to be_successful
        # 19:00 UTC = 3:00 pm ET (3 hours later than 12 pm PT)
        expect(response.body).to include("Sun, Jun 15 @ 3 - 4 pm")
      end
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      sign_in user
      allow_any_instance_of(ApplicationController).
        to receive(:current_user).and_return(user)

      get new_event_url

      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    describe 'when signed in as an admin' do
      it "renders a successful response" do
        sign_in admin

        allow_any_instance_of(ApplicationController).
          to receive(:current_user).and_return(admin)
        get edit_event_url(event)

        expect(response).to be_successful
      end
    end

    describe "when not signed in as an admin" do
      it "returns unauthorized" do
        sign_in user

        get edit_event_url(event)

        expect(response).to have_http_status(:found) # 302 redirect
        expect(response).to redirect_to(events_path)
      end
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Event" do
        sign_in user
        expect {
          post events_url, params: { event: valid_attributes }
        }.to change(Event, :count).by(1)
      end

      it "redirects to the events index" do
        sign_in user
        post events_url, params: { event: valid_attributes }
        expect(response).to redirect_to(events_url)
      end

      it "displays notice if present" do
        sign_in user
        post events_url, params: { event: {
          title: "sample title",
          description: "sample description",
          start_date: 1.day.from_now,
          end_date: 2.days.from_now,
          registration_close_date: 3.days.ago,
          publicly_visible: true
        } }
        follow_redirect!  # flash shows after redirect

        expect(response.body).to include("Event was successfully created")
      end

      it "stores start_date/end_date in UTC when created by user in Pacific time zone" do
        user_pt = create(:user) # default Pacific Time (US & Canada)
        sign_in user_pt
        # datetime-local sends "YYYY-MM-DDTHH:MM" — interpreted in request's Time.zone (PT)
        # 12:00–13:00 PT (PDT) on 2025-06-15 = 19:00–20:00 UTC
        post events_url, params: { event: {
          title: "PT event",
          description: "desc",
          start_date: "2025-06-15T12:00",
          end_date: "2025-06-15T13:00",
          registration_close_date: 1.day.ago,
          publicly_visible: true
        } }

        expect(response).to redirect_to(events_url)
        created = Event.order(created_at: :desc).first
        expect(created.start_date.utc).to eq(Time.utc(2025, 6, 15, 19, 0, 0))
        expect(created.end_date.utc).to eq(Time.utc(2025, 6, 15, 20, 0, 0))
      end

      it "stores start_date/end_date in UTC when created by user in Eastern time zone" do
        user_et = create(:user, time_zone: "America/New_York")
        sign_in user_et
        # 15:00–16:00 ET (EDT) on 2025-06-15 = 19:00–20:00 UTC
        post events_url, params: { event: {
          title: "ET event",
          description: "desc",
          start_date: "2025-06-15T15:00",
          end_date: "2025-06-15T16:00",
          registration_close_date: 1.day.ago,
          publicly_visible: true
        } }

        expect(response).to redirect_to(events_url)
        created = Event.order(created_at: :desc).first
        expect(created.start_date.utc).to eq(Time.utc(2025, 6, 15, 19, 0, 0))
        expect(created.end_date.utc).to eq(Time.utc(2025, 6, 15, 20, 0, 0))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Event" do
        sign_in user
        expect {
          post events_url, params: { event: invalid_attributes }
        }.to change(Event, :count).by(0)
      end

      it "renders a response with validation errors (i.e. to display the 'new' template)" do
        sign_in user
        post events_url, params: { event: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        valid_attributes.merge(
          title: "Updated Event Title"
        )
      end

      context "when signed in as admin" do
        it "updates the requested event" do
          sign_in user
          allow_any_instance_of(ApplicationController).
            to receive(:current_user).and_return(admin)
          patch event_url(event), params: { event: new_attributes }
          event.reload

          expect(event.title).to eq(new_attributes[:title])
        end

        it "redirects to the events index" do
          sign_in user
          allow_any_instance_of(ApplicationController).
            to receive(:current_user).and_return(admin)

          patch event_url(event), params: { event: new_attributes }
          event.reload

          expect(response).to redirect_to(events_url)
        end
      end

      context "when not signed in as an admin" do
        it "returns unauthorized" do
          sign_in user

          patch event_url(event), params: { event: new_attributes }

          expect(response).to have_http_status(:found)
          expect(response).to redirect_to(events_path)
        end
      end
    end

    context "with invalid parameters" do
      it "renders a response with validation errors (i.e. to display the 'edit' template)" do
        event = Event.create!(valid_attributes)
        allow_any_instance_of(ApplicationController).
          to receive(:current_user).and_return(admin)
        patch event_url(event), params: { event: invalid_attributes }
        expect(response).to_not be_successful
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested event" do
      event = Event.create!(valid_attributes)
      sign_in admin
      allow_any_instance_of(ApplicationController).
        to receive(:current_user).and_return(admin)
      expect {
        delete event_url(event)
      }.to change(Event, :count).by(-1)
    end

    it "redirects to the events list" do
      sign_in user
      allow_any_instance_of(ApplicationController).
        to receive(:current_user).and_return(admin)
      delete event_url(event)
      expect(response).to redirect_to(events_url)
    end
  end
end
