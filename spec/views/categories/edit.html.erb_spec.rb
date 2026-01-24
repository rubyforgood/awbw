require "rails_helper"

RSpec.describe "categories/edit", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:category_type) { create(:category_type) }
  let(:category) { create(:category, category_type: category_type) }

  before do
    assign(:category, category)
    assign(:category_types, [ category_type ])
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders the edit category form with metadatum select" do
    render

    # Name field
    assert_select "input[name=?]", "category[name]"

    # Category Type select
    assert_select "select[name=?]", "category[category_type_id]"

    # Published checkbox
    assert_select "input[name=?][type=checkbox]", "category[published]"
  end
end
