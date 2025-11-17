require 'rails_helper'

RSpec.describe "projects/new", type: :view do
    let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  before do
    assign(:project, Project.new)
    allow(view).to receive(:current_user).and_return(admin)
    render
  end

  it "renders new project form" do
    assert_select "form[action=?][method=?]", projects_path, "post" do

      assert_select "select[name=?]", "project[windows_type_id]"

      assert_select "textarea[name=?]", "project[name]"

      assert_select "textarea[name=?]", "project[description]"

      assert_select "select[name=?]", "project[project_status_id]"

      assert_select "input[name=?]", "project[inactive]"

      assert_select "textarea[name=?]", "project[notes]"
    end
  end
end
