require 'rails_helper'

RSpec.describe "project_statuses/edit", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:project_status) { create(:project_status) }

  before(:each) do
    sign_in admin
    assign(:project_status, project_status)
  end

  it "renders the edit project_status form" do
    render

    assert_select "form[action=?][method=?]", project_status_path(project_status), "post" do
      assert_select "input[name=?]", "project_status[name]"
    end
  end
end
