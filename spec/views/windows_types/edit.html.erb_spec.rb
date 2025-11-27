require 'rails_helper'

RSpec.describe "windows_types/edit", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:windows_type) { create(:windows_type) }
  let(:categories) { create_list(:category, 3, :category_age_range) }

  before(:each) do
    assign(:windows_type, windows_type)
    allow(view).to receive(:current_user).and_return(admin)
    assign(:windows_types, [])
    assign(:categories, categories)
  end

  it "renders the edit windows_type form" do
    render

    assert_select "form[action=?][method=?]", windows_type_path(windows_type), "post" do

      assert_select "textarea[name=?]", "windows_type[name]"

      # TEXT FIELDS
      assert_select "textarea[name=?]", "windows_type[name]"

      # READONLY FIELDS (since this is used in code, we're not exposing it to the user)
      assert_select "input[name=?][readonly]", "windows_type[short_name]"

      # CHECKBOXES FOR CATEGORIES
      categories.each do |cat|
        assert_select "input[type=?][name=?][value=?]",
                      "checkbox",
                      "windows_type[category_ids][]",
                      cat.id.to_s
      end
    end
  end
end
