# spec/views/users/new.html.erb_spec.rb
require 'rails_helper'

RSpec.describe "users/new.html.erb", type: :view do
  let!(:combined_perm) { Permission.create!(security_cat: "Combined Adult and Children's Windows") }
  let!(:adult_perm)    { Permission.create!(security_cat: "Adult Windows") }
  let!(:children_perm) { Permission.create!(security_cat: "Children's Windows") }

  let(:user) { build_stubbed(:user) }

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

      assert_select "textarea[name=?]", "user[address]"

      assert_select "textarea[name=?]", "user[address2]"

      assert_select "textarea[name=?]", "user[city]"

      assert_select "textarea[name=?]", "user[city2]"

      assert_select "input[name=?]", "user[state]"

      assert_select "input[name=?]", "user[state2]"

      assert_select "input[name=?]", "user[zip]"

      assert_select "input[name=?]", "user[zip2]"

      assert_select "input[name=?]", "user[phone]"

      assert_select "input[name=?]", "user[phone2]"

      assert_select "input[name=?]", "user[phone3]"

      assert_select "input[name=?]", "user[best_time_to_call]"

      assert_select "textarea[name=?]", "user[notes]"

      assert_select "input[name=?]", "user[inactive]"

      assert_select "input[name=?]", "user[super_user]"
    end
  end
end
