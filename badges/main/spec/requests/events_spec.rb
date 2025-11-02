require 'rails_helper'

RSpec.describe "/events", type: :request do
  before do
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
  end

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
  let(:admin) { create(:user, super_user: true) }
  let(:event) { Event.create!(valid_attributes) }

  describe "GET /index" do
    it "renders a successful response" do
      sign_in user
      get events_url
      puts "=====Status: #{response.status}"
      puts "Error snippet: #{response.body.scan(/<pre.*?>(.*?)<\/pre>/m)}"
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      sign_in user

      allow_any_instance_of(ApplicationController).
        to receive(:current_admin).and_return(true)
      get event_url(event)

      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      sign_in user
      allow_any_instance_of(ApplicationController).
        to receive(:current_admin).and_return(true)

      get new_event_url

      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    describe 'when signed in as an admin' do
      it "renders a successful response" do
        sign_in admin
  
        allow_any_instance_of(ApplicationController).
          to receive(:current_admin).and_return(true)
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
      let(:new_attributes) {
        skip("Add a hash of attributes valid for your model")
      }

      context "when signed in as admin" do
        it "updates the requested event" do
          sign_in user
          allow_any_instance_of(ApplicationController).
            to receive(:current_admin).and_return(true)
          patch event_url(event), params: { event: new_attributes }
          event.reload
          
          expect(event.title).to eq(new_attributes[:title])
        end

        it "redirects to the event" do
          sign_in user
          allow_any_instance_of(ApplicationController).
            to receive(:current_admin).and_return(true)

          patch event_url(event), params: { event: new_attributes }
          event.reload

          expect(response).to redirect_to(event_url(event))
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
          to receive(:current_admin).and_return(true)
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
        to receive(:current_admin).and_return(true)
      expect {
        delete event_url(event)
      }.to change(Event, :count).by(-1)
    end

    it "redirects to the events list" do
      sign_in user
      allow_any_instance_of(ApplicationController).
        to receive(:current_admin).and_return(true)
      delete event_url(event)
      expect(response).to redirect_to(events_url)
    end
  end
end
