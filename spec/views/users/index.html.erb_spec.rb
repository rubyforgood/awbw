require "rails_helper"

RSpec.describe "users/index", type: :view do
  let(:admin_user) { create(:user, :admin) }

  before do
    allow(view).to receive(:current_user).and_return(admin_user)
  end

  context "when users have facilitators" do
    before do
      @users = create_list(:user, 2, :with_facilitator) # Factory should build facilitator + avatar if needed

      paginated = WillPaginate::Collection.create(1, 10, @users.size) do |pager|
        pager.replace(@users)
      end

      assign(:users, paginated)
      assign(:users_count, @users.size)
    end

    it "renders facilitator profile buttons instead of 'Create facilitator'" do
      render

      # Two rows
      expect(rendered).to have_selector("table tbody tr", count: 2)

      @users.each do |user|
        facilitator = user.facilitator

        # The helper output (button) must appear
        expect(rendered).to include(facilitator.name)

        # Should NOT show "Create facilitator"
        expect(rendered).not_to include("Create facilitator")
      end
    end
  end

  context "when a user has NO facilitator" do
    let!(:user_without_facilitator) { create(:user) }

    before do
      paginated = WillPaginate::Collection.create(1, 10, 1) do |pager|
        pager.replace([user_without_facilitator])
      end

      assign(:users, paginated)
      assign(:users_count, 1)
    end

    it "shows 'Create facilitator' button" do
      render

      expect(rendered).to include("Create facilitator")
      expect(rendered).to have_link(
                            "Create facilitator",
                            href: new_facilitator_path(user_id: user_without_facilitator.id)
                          )
    end
  end

  context "general index behavior" do
    before do
      users = create_list(:user, 3)

      paginated = WillPaginate::Collection.create(1, 10, users.size) do |pager|
        pager.replace(users)
      end

      assign(:users, paginated)
      assign(:users_count, users.size)
    end

    it "renders correct table structure" do
      render

      expect(rendered).to have_selector("table thead tr th", text: "Name")
      expect(rendered).to have_selector("table thead tr th", text: "Email")
      expect(rendered).to have_selector("table tbody tr", count: 3)
    end
  end
end
