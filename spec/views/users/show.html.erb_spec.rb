require "rails_helper"

RSpec.describe "users/show", type: :view do
  let(:user) do
    create(
      :user,
      email: "email@example.com",
      super_user: false,
      sign_in_count: 3,
      current_sign_in_at: 1.day.ago,
      last_sign_in_at: 2.days.ago
    )
  end

  before do
    assign(:user, user)
  end

  # --------------------------------------------------
  # ADMIN VIEW
  # --------------------------------------------------
  context "when current user is an admin" do
    let(:admin) { create(:user, :admin) }

    before do
      allow(view).to receive(:current_user).and_return(admin)
      render
    end

    it "shows navigation buttons" do
      expect(rendered).to have_link("Users", href: users_path)
      expect(rendered).to have_link("Edit", href: edit_user_path(user))
    end

    it "renders identity info" do
      expect(rendered).to include("email@example.com")
    end

    it "renders account status section" do
      expect(rendered).to include("Account status")
      expect(rendered).to include("Active")
      expect(rendered).to include("Admin")
    end

    it "renders authentication data when available" do
      expect(rendered).to include("Sign-in count")
      expect(rendered).to include("3")

      expect(rendered).to include("Current sign-in")
      expect(rendered).to include(I18n.l(user.current_sign_in_at, format: :long))
    end

    it "renders audit timestamps" do
      expect(rendered).to include("Created at")
      expect(rendered).to include(I18n.l(user.updated_at, format: :long))
    end
  end

  # --------------------------------------------------
  # NON-ADMIN VIEW
  # --------------------------------------------------
  context "when current user is not an admin" do
    let(:regular_user) { create(:user) }

    before do
      allow(view).to receive(:current_user).and_return(regular_user)
      render
    end

    it "redirects to root" do
      # redirect to root is handled by request spec, so we just test that the view doesn't render admin-only content
      expect(rendered).not_to have_link("Users")
      expect(rendered).not_to have_link("Edit")
    end
  end

  # --------------------------------------------------
  # FACILITATOR ASSOCIATION
  # --------------------------------------------------
  context "when user has no person" do
    let(:admin) { create(:user, :admin) }

    before do
      allow(view).to receive(:current_user).and_return(admin)
      render
    end

    it "shows person creation prompt" do
      expect(rendered).to include("Not associated with a person")
      expect(rendered).to have_link("Create person")
    end
  end
end
