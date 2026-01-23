require "rails_helper"

RSpec.describe "shared/_navbar", type: :view do
  let(:regular_user) { create(:user, super_user: false) }
  let(:admin_user)   { create(:user, super_user: true) }

  def render_nav
    render partial: "shared/navbar"
  end

  context "when not logged in" do
    before do
      allow(view).to receive(:current_user).and_return(nil)
      allow(view).to receive(:user_signed_in?).and_return(false)
      render_nav
    end

    it "does not show admin-only links" do
      expect(rendered).not_to include("Facilitators")
      expect(rendered).not_to include("Organizations")
      expect(rendered).not_to include("Admin")
    end

    it "does not render avatar menu" do
      expect(rendered).not_to have_css("#avatar-dropdown")
    end
  end

  context "when logged in as a regular user" do
    before do
      allow(view).to receive(:current_user).and_return(regular_user)
      allow(view).to receive(:user_signed_in?).and_return(true)
      render_nav
    end

    it "shows general navigation" do
      expect(rendered).to include("Curriculum")
      expect(rendered).to include("Community")
      expect(rendered).to include("Help")
    end

    it "does not show admin-only links" do
      expect(rendered).not_to include("Facilitators")
      expect(rendered).not_to include("Organizations")
      expect(rendered).not_to include("Admin")
    end

    it "shows personal menu items" do
      expect(rendered).to include("My bookmarks")
      expect(rendered).to include("My workshop logs")
      expect(rendered).to include("Logout")
    end
  end

  context "when logged in as a super user" do
    before do
      allow(view).to receive(:current_user).and_return(admin_user)
      allow(view).to receive(:user_signed_in?).and_return(true)
      render_nav
    end

    it "shows admin-only links in Community menu" do
      expect(rendered).to include("Facilitators")
      expect(rendered).to include("Organizations")
    end

    it "shows Admin link in avatar menu" do
      expect(rendered).to include("Admin")
    end

    it "shows profile and team links" do
      expect(rendered).to include("My profile")
    end
  end
end
