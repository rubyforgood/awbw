require "rails_helper"

RSpec.describe "Events::Copies", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:event) { create(:event, title: "Spring training") }

  describe "GET /events/:event_id/copy/new" do
    it "shows the copy form to admins" do
      sign_in admin

      get new_event_copy_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Copy of Spring training")
    end

    it "is closed to the event's owner when they aren't an admin" do
      sign_in event.created_by

      get new_event_copy_path(event)

      expect(response).to redirect_to(root_path)
    end
  end

  it "links to the copy form from the event's edit page" do
    sign_in admin

    get edit_event_path(event)

    expect(response.body).to include(new_event_copy_path(event))
  end

  describe "POST /events/:event_id/copy" do
    before { sign_in admin }

    it "creates the copy and opens it for editing" do
      expect {
        post event_copy_path(event), params: { title: "Fall training", start_on: "2027-09-14" }
      }.to change(Event, :count).by(1)

      copy = Event.order(:id).last
      expect(response).to redirect_to(edit_event_path(copy))
      expect(copy).to have_attributes(title: "Fall training", starts_on: Date.new(2027, 9, 14), published: false)
    end

    it "flashes a warning for anything the copy had to skip" do
      asset = create(:primary_asset, :with_file, owner: event)
      asset.file.blob.service.delete(asset.file.blob.key)

      post event_copy_path(event), params: { title: "Fall training", start_on: "2027-09-14" }

      expect(response).to redirect_to(edit_event_path(Event.order(:id).last))
      expect(flash[:warning]).to match(/PrimaryAsset image not copied/)
    end

    it "re-renders the form when the start date is missing" do
      expect {
        post event_copy_path(event), params: { title: "Fall training", start_on: "" }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "keeps the source title when none is given" do
      post event_copy_path(event), params: { title: "", start_on: "2027-09-14" }

      expect(Event.order(:id).last.title).to eq("Spring training")
    end

    it "re-renders the form when the title is too long" do
      expect {
        post event_copy_path(event), params: { title: "x" * 256, start_on: "2027-09-14" }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Title is too long")
    end
  end
end
