require 'rails_helper'

RSpec.describe "windows_types/new", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:categories) { create_list(:category, 3, :category_age_range) }

  before do
    assign(:windows_type, WindowsType.new(
      name: "",
      short_name: "",
      legacy_id: nil
    ))
    allow(view).to receive(:current_user).and_return(admin)
    assign(:categories, categories)
  end

  it "renders the new windows_type form" do
    render

    assert_select "form[action=?][method=?]", windows_types_path, "post" do

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
