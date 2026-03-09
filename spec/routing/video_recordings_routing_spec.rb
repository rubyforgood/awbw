require "rails_helper"

RSpec.describe VideoRecordingsController, type: :routing do
  describe "routing" do
    it "routes /video_recordings to video_recordings#index" do
      expect(get: "/video_recordings").to route_to("video_recordings#index")
    end

    it "routes /video_recordings/new to video_recordings#new" do
      expect(get: "/video_recordings/new").to route_to("video_recordings#new")
    end

    it "routes /video_recordings/1 to video_recordings#show" do
      expect(get: "/video_recordings/1").to route_to("video_recordings#show", id: "1")
    end

    it "routes /video_recordings/1/edit to video_recordings#edit" do
      expect(get: "/video_recordings/1/edit").to route_to("video_recordings#edit", id: "1")
    end

    it "routes POST /video_recordings to video_recordings#create" do
      expect(post: "/video_recordings").to route_to("video_recordings#create")
    end

    it "routes PUT /video_recordings/1 to video_recordings#update" do
      expect(put: "/video_recordings/1").to route_to("video_recordings#update", id: "1")
    end

    it "routes PATCH /video_recordings/1 to video_recordings#update" do
      expect(patch: "/video_recordings/1").to route_to("video_recordings#update", id: "1")
    end

    it "routes DELETE /video_recordings/1 to video_recordings#destroy" do
      expect(delete: "/video_recordings/1").to route_to("video_recordings#destroy", id: "1")
    end
  end
end
