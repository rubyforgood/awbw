require 'rails_helper'

RSpec.describe "projects/edit", type: :view do
    let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:project_status) { create(:project_status) }
  let(:windows_type) { create(:windows_type) }
  
  let(:project) {
    Project.create!(
      windows_type: windows_type,
      project_status: project_status,
      location: nil,
      name: "MyString",
      description: "MyString",
      inactive: false,
      notes: "MyText"
    )
  }

  before(:each) do
    assign(:project, project)
    allow(view).to receive(:current_user).and_return(admin)
    render
  end

  it "renders the edit project form" do
    assert_select "form[action=?][method=?]", project_path(project), "post" do

      assert_select "select[name=?]", "project[windows_type_id]"

      assert_select "textarea[name=?]", "project[name]"

      assert_select "textarea[name=?]", "project[description]"

      assert_select "select[name=?]", "project[project_status_id]"

      assert_select "input[name=?]", "project[inactive]"

      assert_select "textarea[name=?]", "project[notes]"
    end
  end
end
