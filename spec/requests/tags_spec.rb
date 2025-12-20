# spec/requests/tags_spec.rb
require "rails_helper"

RSpec.describe "Tags index", type: :request do
	let!(:sector) do
		create(:sector, :published, name: "Youth")
	end

	let!(:category_type) do
		create(:category_type, name: "Theme")
	end

	let!(:category) do
		create(
			:category,
			:published,
			name: "Healing",
			category_type: category_type
		)
	end

	describe "as a regular user" do
		let(:user) { create(:user) }

		before do
			sign_in user
			get tags_path
		end

		it "renders successfully" do
			expect(response).to have_http_status(:ok)
		end

		it "shows published sectors" do
			expect(response.body).to include("Youth")
		end

		it "shows published categories" do
			expect(response.body).to include("Healing")
		end

		it "does NOT show admin-only controls" do
			expect(response.body).not_to include("Manage sectors")
			expect(response.body).not_to include("Manage categories")
		end
	end

	describe "as a super user (admin)" do
		let(:admin) { create(:user, :admin) }

		before do
			sign_in admin
			get tags_path
		end

		it "renders successfully" do
			expect(response).to have_http_status(:ok)
		end

		it "shows admin controls" do
			expect(response.body).to include("Manage sectors")
			expect(response.body).to include("Manage categories")
		end

		it "still shows sectors and categories" do
			expect(response.body).to include("Youth")
			expect(response.body).to include("Healing")
		end
	end

	describe "when not signed in" do
		it "redirects to sign-in" do
			get tags_path
			expect(response).to redirect_to(new_user_session_path)
		end
	end
end
