require 'rails_helper'

RSpec.describe "projects/edit", type: :view do
  let(:project) {
    Project.create!(
      windows_type: nil,
      name: "MyString",
      description: "MyString",
      project_status: 1,
      location: nil,
      district: "MyString",
      locality: "MyString",
      inactive: false,
      notes: "MyText"
    )
  }

  before(:each) do
    assign(:project, project)
  end

  it "renders the edit project form" do
    render

    assert_select "form[action=?][method=?]", project_path(project), "post" do

      assert_select "input[name=?]", "project[windows_type_id]"

      assert_select "input[name=?]", "project[name]"

      assert_select "input[name=?]", "project[description]"

      assert_select "input[name=?]", "project[project_status]"

      assert_select "input[name=?]", "project[location_id]"

      assert_select "input[name=?]", "project[district]"

      assert_select "input[name=?]", "project[locality]"

      assert_select "input[name=?]", "project[inactive]"

      assert_select "textarea[name=?]", "project[notes]"
    end
  end
end
