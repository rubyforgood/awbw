require 'rails_helper'

RSpec.describe "project_statuses/new", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:project_status) { build(:project_status) }

  before do
    allow(view).to receive(:current_user).and_return(admin)
    assign(:project_status, project_status)
  end

  it "renders new project_status form" do
    render

    assert_select "form[action=?]", project_statuses_path do
      assert_select "input[name=?]", "project_status[name]"
    end
  end
end
