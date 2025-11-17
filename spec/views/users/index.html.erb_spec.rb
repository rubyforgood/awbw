require 'rails_helper'

RSpec.describe "users/index", type: :view do
  let(:admin_user) { create(:user, :admin) } # or super_user trait

  before(:each) do
    allow(view).to receive(:current_user).and_return(admin_user) # Stub current_user for Devise
    users = create_list(:user, 3, first_name: "Alice")
    paginated_users = WillPaginate::Collection.create(1, 10, users.size) do |pager|
      pager.replace(users)
    end
    assign(:users, paginated_users)
  end

  it "renders a list of users" do
    render

    assert_select "table tbody tr", count: 3
    assert_select "table tbody tr td", text: /Alice/
  end
end
