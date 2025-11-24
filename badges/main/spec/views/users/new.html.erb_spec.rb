# spec/views/users/new.html.erb_spec.rb
require 'rails_helper'

RSpec.describe "users/new.html.erb", type: :view do
  let(:user) { build_stubbed(:user, :admin) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:user, User.new)
    render
  end

  it "renders new user form" do
    render

    assert_select "form[action=?][method=?]", users_path, "post" do

      assert_select "input[name=?]", "user[first_name]"

      assert_select "input[name=?]", "user[last_name]"

      assert_select "input[name=?]", "user[email]"

      assert_select "textarea[name=?]", "user[notes]"

      assert_select "input[name=?]", "user[inactive]"

      assert_select "input[name=?]", "user[super_user]"
    end
  end
end
