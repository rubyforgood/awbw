require 'rails_helper'

RSpec.describe "tutorials/edit", type: :view do
  let(:admin) { create(:user, :admin) }

  let(:tutorial) {
    sign_in admin

    Tutorial.create!(
      title: "MyString",
      body: "MyText",
      featured: false,
      published: false,
      position: 1,
      youtube_url: "MyString"
    ).decorate
  }

  before(:each) do
    assign(:tutorial, tutorial)
  end

  it "renders the edit tutorial form" do
    render

    assert_select "form[action=?][method=?]", tutorial_path(tutorial), "post" do

      assert_select "textarea[name=?]", "tutorial[title]"
      assert_select "textarea[name=?]", "tutorial[body]"
      assert_select "input[name=?][type=checkbox]", "tutorial[published]"
      assert_select "input[name=?][type=checkbox]", "tutorial[featured]"
      assert_select "input[name=?]", "tutorial[position]"
      assert_select "textarea[name=?]", "tutorial[youtube_url]"
    end
  end
end
