require 'rails_helper'

RSpec.describe "users/index", type: :view do
  before(:each) do
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
