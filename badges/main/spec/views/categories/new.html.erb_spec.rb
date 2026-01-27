require 'rails_helper'

RSpec.describe "categories/new", type: :view do
  let(:category) { Category.new }
  let(:category_types) { create_list(:category_type, 3) }

  before do
    assign(:category, category)
    assign(:category_types, category_types)

    allow(view).to receive(:current_user).and_return(create(:user, :admin))
  end

  it "renders the new category form" do
    render template: "categories/new"

    assert_select "form[action=?][method=?]", categories_path, "post" do
      assert_select "input[name=?]", "category[name]"
      assert_select "select[name=?]", "category[category_type_id]"
      assert_select "input[name=?]", "category[published]"
    end
  end
end
