require 'rails_helper'

RSpec.describe "users/new", type: :view do
  before(:each) do
    assign(:user, User.new(
      first_name: "MyString",
      last_name: "MyString",
      email: "MyString@example.com",
      password: "MyString",
      password_confirmation: "MyString",
      address: "MyString",
      address2: "MyString",
      city: "MyString",
      city2: "MyString",
      state: "MyString",
      state2: "MyString",
      zip: "MyString",
      zip2: "MyString",
      phone: "MyString",
      phone2: "MyString",
      phone3: "MyString",
      best_time_to_call: "MyString",
      comment: "MyText",
      notes: "MyText",
      inactive: false,
      legacy: false,
      super_user: false,
      sign_in_count: 1,
      current_sign_in_ip: "MyString",
      last_sign_in_ip: "MyString",
      subscribecode: "MyString"
    ))
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
