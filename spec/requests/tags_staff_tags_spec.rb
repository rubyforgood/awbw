require "rails_helper"

RSpec.describe "Staff tags on the tag-browsing pages", type: :request do
  let!(:published_tag) { create(:staff_tag, name: "Highlight roster") }
  let!(:unpublished_tag) { create(:staff_tag, :unpublished, name: "Legacy roster") }

  shared_examples "an admin-only staff tags section" do |path_helper|
    it "shows published staff tags to admins, linking to the filtered people roster" do
      sign_in create(:user, :admin)
      get public_send(path_helper)

      expect(response.body).to include("Staff tags")
      expect(response.body).to include("Highlight roster")
      expect(response.body).to include("staff_tag_ids=#{published_tag.id}")
      # Unpublished tags stay out of the browse section.
      expect(response.body).not_to include("Legacy roster")
    end

    it "hides the section from anonymous visitors" do
      get public_send(path_helper)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Highlight roster")
    end

    it "hides the section from non-admins" do
      sign_in create(:user, super_user: false)
      get public_send(path_helper)

      expect(response.body).not_to include("Highlight roster")
    end
  end

  describe "GET /tags" do
    it_behaves_like "an admin-only staff tags section", :tags_path
  end

  describe "GET /taggings" do
    it_behaves_like "an admin-only staff tags section", :taggings_path
  end
end
