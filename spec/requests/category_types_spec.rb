require "rails_helper"

RSpec.describe "/category_types", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /new" do
    it "renders the published, story specific, and profile specific flags with shared copy" do
      get new_category_type_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="category_type[published]"')
      expect(response.body).to include('name="category_type[story_specific]"')
      expect(response.body).to include('name="category_type[profile_specific]"')

      # Published is repurposed here, so it uses the child-category definition.
      expect(response.body).to include("Hides all child categories")
      expect(response.body).to include(VisibilityFlagsHelper::FLAG_DEFINITIONS[:category_type_published][:description])
      expect(response.body).to include(VisibilityFlagsHelper::FLAG_DEFINITIONS[:story_specific][:hint])
    end
  end
end
