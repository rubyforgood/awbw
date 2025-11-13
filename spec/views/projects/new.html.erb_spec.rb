require 'rails_helper'

RSpec.describe "projects/new", type: :view do
  let!(:combined_perm) { create(:permission, :combined) }
  let!(:adult_perm)    { create(:permission, :adult) }
  let!(:children_perm) { create(:permission, :children) }
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

      assert_select "input[name=?]", "project[name]"

      assert_select "textarea[name=?]", "project[description]"

      assert_select "select[name=?]", "project[project_status_id]"

      assert_select "select[name=?]", "project[location_id]"

      assert_select "input[name=?]", "project[district]"

      assert_select "input[name=?]", "project[locality]"

      assert_select "input[name=?]", "project[inactive]"

      assert_select "textarea[name=?]", "project[notes]"
    end
  end
end
