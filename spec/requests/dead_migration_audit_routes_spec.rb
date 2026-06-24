require "rails_helper"

# Leftover "migration audit" routes pointed at controllers that never existed
# (ImagesController, AttachmentsController, MediaFilesController, Images::*).
# A bot probing GET /images/index.php matched `resources :images` and dispatched
# to the missing ImagesController, raising ActionDispatch::MissingController (a
# 500) instead of a plain 404. These paths must be unrouted, i.e. raise a
# routing error rather than a missing-controller error.
RSpec.describe "Removed migration-audit routes", type: :request do
  [
    "/images/index.php",
    "/images/1",
    "/images/primary_images/1",
    "/images/gallery_images/1",
    "/images/rich_texts/1",
    "/attachments/1",
    "/media_files/1"
  ].each do |path|
    it "404s for GET #{path} instead of erroring on a missing controller" do
      get path
      expect(response).to have_http_status(:not_found)
    end
  end
end
