require 'rails_helper'

RSpec.describe "organizations/new", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  before do
    assign(:organization, Organization.new)
    allow(view).to receive(:current_user).and_return(admin)
    allow(view).to receive(:allowed_to?).and_return(true)
  end

  it "renders new organization form" do
    render
    assert_select "form[action=?][method=?]", organizations_path, "post" do
      assert_select "textarea[name=?]", "organization[name]"

      assert_select "textarea[name=?]", "organization[description]"
    end
    # The Windows audience dropdown was replaced by the age-range chip picker.
    assert_select "select[name=?]", "organization[windows_type_id]", false
  end

  it "renders the cocoon age-range chip picker instead of the windows dropdown" do
    assign(:age_ranges_collection, [ [ "Children (0-12)", 1 ], [ "Adults (18+)", 2 ] ])
    assign(:current_age_range_category_ids, [])
    render
    expect(rendered).to include("primary-tag")
    expect(rendered).to include("Add age range")
    expect(rendered).to include("Children (0-12)")
  end
end
