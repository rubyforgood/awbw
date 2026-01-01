require 'rails_helper'

RSpec.describe "tutorials/new", type: :view do
  let(:admin) { create(:user, :admin) }

  before(:each) do
    sign_in admin

    assign(:tutorial, Tutorial.new(
      title: "MyString",
      body: "MyText",
      featured: false,
      published: false,
      position: 1,
      youtube_url: "MyString"
    ).decorate)
  end

  it "renders new tutorial form" do
    render

    assert_select "form[action=?][method=?]", tutorials_path, "post" do
      assert_select "textarea[name=?]", "tutorial[title]"
      assert_select "textarea[name=?]", "tutorial[body]"
      assert_select "input[name=?][type=checkbox]", "tutorial[published]"
      assert_select "input[name=?][type=checkbox]", "tutorial[featured]"
      assert_select "input[name=?]", "tutorial[position]"
      assert_select "textarea[name=?]", "tutorial[youtube_url]"
    end
  end
end
