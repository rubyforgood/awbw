require 'rails_helper'

RSpec.describe "categories/edit", type: :view do
  let(:category) {
    Category.create!(
      name: "MyString",
      category_type: nil,
      published: false
    )
  }

  before(:each) do
    assign(:category, category)
  end

  it "renders the edit category form" do
    render

    assert_select "form[action=?][method=?]", category_path(category), "post" do

      assert_select "input[name=?]", "category[name]"

      assert_select "input[name=?]", "category[category_type_id]"

      assert_select "input[name=?]", "category[published]"
    end
  end
end
