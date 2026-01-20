require "rails_helper"

RSpec.describe "users/show", type: :view do
  let(:user) do
    create(
      :user,
      name: "Jane Artist",
      email: "Email@example.com",
      phone: "555-1234",
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
  context "when current user is a super user" do
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
      expect(rendered).to include("Jane Artist")
      expect(rendered).to include("Email@example.com")
      expect(rendered).to include("555-1234")
    end

    it "renders account status section" do
      expect(rendered).to include("Account status")
      expect(rendered).to include("Active")
      expect(rendered).to include("Super user")
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
  context "when current user is not a super user" do
    let(:regular_user) { create(:user) }

    before do
      allow(view).to receive(:current_user).and_return(regular_user)
      render
    end

    it "does not show admin buttons" do
      expect(rendered).not_to have_link("Users")
      expect(rendered).not_to have_link("Edit")
    end
  end

  # --------------------------------------------------
  # FACILITATOR ASSOCIATION
  # --------------------------------------------------
  context "when user has no facilitator" do
    let(:admin) { create(:user, :admin) }

    before do
      allow(view).to receive(:current_user).and_return(admin)
      render
    end

    it "shows facilitator creation prompt" do
      expect(rendered).to include("Not associated with a facilitator")
      expect(rendered).to have_link("Create facilitator")
    end
  end
end
