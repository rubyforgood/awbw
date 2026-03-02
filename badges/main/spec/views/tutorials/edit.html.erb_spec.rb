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
    assign(:categories_grouped, Category.includes(:category_type).published.order(:position, :name)
      .group_by(&:category_type).select { |type, _| type.nil? || type.published? }
      .sort_by { |type, _| type&.name.to_s.downcase })
    assign(:sectors, Sector.published.order(:name))
  end

  it "renders the edit tutorial form" do
    render

    assert_select "form[action=?][method=?]", tutorial_path(tutorial), "post" do
      assert_select "textarea[name=?]", "tutorial[title]"
      assert_select "input[name=?][type=?]", "tutorial[rhino_body]", "hidden"
      assert_select "input[name=?][type=checkbox]", "tutorial[published]"
      assert_select "input[name=?][type=checkbox]", "tutorial[featured]"
      assert_select "input[name=?]", "tutorial[position]"
      assert_select "textarea[name=?]", "tutorial[youtube_url]"
    end
  end
end
