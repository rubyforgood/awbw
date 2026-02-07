require "rails_helper"

RSpec.describe "Events", type: :request do
  let(:user)  { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }

  let(:valid_params) do
    {
      event: {
        title: "Sample title",
        description: "Sample description",
        start_date: 1.day.from_now,
        end_date: 2.days.from_now,
        registration_close_date: 3.days.ago,
        published: true
      }
    }
  end

  let(:invalid_params) do
    { event: { title: "" } }
  end

  describe "GET /index" do
    it "is successful for signed in user" do
      sign_in user
      get events_path
      expect(response).to have_http_status(:ok)
    end

    context "when user time_zone is set" do
      # 19:00 UTC = 12:00 noon PT = 15:00 (3 pm) ET (June 15, 2025 with DST)
      let(:utc_start) { Time.utc(2025, 6, 15, 19, 0, 0) }
      let(:utc_end)   { Time.utc(2025, 6, 15, 20, 0, 0) }
      let!(:event_with_fixed_times) do
        create(:event, :published,
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
        expect(response.body).to include("All times displayed in (GMT-08:00) Pacific Time")
      end

      it "displays start time in Eastern for user with time_zone America/New_York" do
        user_et = create(:user, time_zone: "Eastern Time (US & Canada)")
        sign_in user_et
        get event_url(event_with_fixed_times)

        expect(response).to be_successful
        # 19:00 UTC = 3:00 pm ET (3 hours later than 12 pm PT)
        expect(response.body).to include("Sun, Jun 15 @ 3 - 4 pm")
        expect(response.body).to include("All times displayed in (GMT-05:00) Eastern Time")
      end
    end
  end

  describe "GET /new" do
    context "as admin" do
      it "renders successfully" do
        sign_in admin
        get new_event_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as non-admin" do
      it "redirects" do
        sign_in user
        get new_event_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /create" do
    context "as admin" do
      before { sign_in admin }

      it "creates event" do
        expect {
          post events_path, params: valid_params
        }.to change(Event, :count).by(1)
      end

      it "redirects" do
        post events_path, params: valid_params
        expect(response).to redirect_to(events_path)
      end

      it "stores start_date/end_date in UTC when created by user in Pacific time zone" do
        admin_pt = create(:user, :admin, time_zone: "Pacific Time (US & Canada)")
        sign_in admin_pt
        # datetime-local sends "YYYY-MM-DDTHH:MM" — interpreted in request's Time.zone (PT)
        # 12:00–13:00 PT (PDT) on 2025-06-15 = 19:00–20:00 UTC
        post events_url, params: { event: {
          title: "PT event",
          description: "desc",
          start_date: "2025-06-15T12:00",
          end_date: "2025-06-15T13:00",
          registration_close_date: 1.day.ago,
          public: true
        } }

        expect(response).to redirect_to(events_url)
        created = Event.order(created_at: :desc).first
        expect(created.start_date.utc).to eq(Time.utc(2025, 6, 15, 19, 0, 0))
        expect(created.end_date.utc).to eq(Time.utc(2025, 6, 15, 20, 0, 0))
      end

      it "stores start_date/end_date in UTC when created by user in Eastern time zone" do
        admin_et = create(:user, :admin, time_zone: "Eastern Time (US & Canada)")
        sign_in admin_et
        # 15:00–16:00 ET (EDT) on 2025-06-15 = 19:00–20:00 UTC
        post events_url, params: { event: {
          title: "ET event",
          description: "desc",
          start_date: "2025-06-15T15:00",
          end_date: "2025-06-15T16:00",
          registration_close_date: 1.day.ago,
          public: true
        } }

        expect(response).to redirect_to(events_url)
        created = Event.order(created_at: :desc).first
        expect(created.start_date.utc).to eq(Time.utc(2025, 6, 15, 19, 0, 0))
        expect(created.end_date.utc).to eq(Time.utc(2025, 6, 15, 20, 0, 0))
      end
    end

    context "as non-admin" do
      before { sign_in user }

      it "does not create event" do
        expect {
          post events_path, params: valid_params
        }.not_to change(Event, :count)
      end

      it "redirects" do
        post events_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /update" do
    let(:update_params) { { event: { title: "Updated" } } }

    context "as admin" do
      before { sign_in admin }

      it "updates event" do
        patch event_path(event), params: update_params
        expect(event.reload.title).to eq("Updated")
      end
    end

    context "as non-admin" do
      before { sign_in user }

      it "does not update" do
        patch event_path(event), params: update_params
        expect(event.reload.title).not_to eq("Updated")
      end

      it "redirects" do
        patch event_path(event), params: update_params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /destroy" do
    context "as admin" do
      before { sign_in admin }

      it "destroys event" do
        event
        expect {
          delete event_path(event)
        }.to change(Event, :count).by(-1)
      end
    end

    context "as non-admin" do
      before { sign_in user }

      it "does not destroy" do
        event
        expect {
          delete event_path(event)
        }.not_to change(Event, :count)
      end
    end
  end
end
