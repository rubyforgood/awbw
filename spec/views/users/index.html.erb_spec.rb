require "rails_helper"

RSpec.describe "users/index", type: :view do
  let(:admin_user) { create(:user, :admin) }

  before do
    allow(view).to receive(:current_user).and_return(admin_user)
  end

  context "when users have people" do
    before do
      @users = create_list(:user, 2, :with_person) # Factory should build person + avatar if needed

      paginated = WillPaginate::Collection.create(1, 10, @users.size) do |pager|
        pager.replace(@users)
      end

      assign(:users, paginated)
      assign(:users_count, @users.size)
    end

    it "renders person profile buttons instead of 'Create person'" do
      render

      # Two rows
      expect(rendered).to have_selector("table tbody tr", count: 2)

      @users.each do |user|
        person = user.person

        # The helper output (button) must appear
        expect(rendered).to include(person.name)

        # Should NOT show "Create person"
        expect(rendered).not_to include("Create person")
      end
    end
  end

  context "when a user has NO person" do
    let!(:user_without_person) { create(:user) }

    before do
      paginated = WillPaginate::Collection.create(1, 10, 1) do |pager|
        pager.replace([ user_without_person ])
      end

      assign(:users, paginated)
      assign(:users_count, 1)
    end

    it "shows 'Create person' button" do
      render

      expect(rendered).to include("Create person")
      expect(rendered).to have_link(
                            "Create person",
                            href: new_person_path(user_id: user_without_person.id)
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
