require 'rails_helper'

RSpec.describe "project_statuses/index", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:project_status1) { create(:project_status, name: "Active") }
  let(:project_status2) { create(:project_status, name: "Suspended") }

  before(:each) do
    assign(:project_statuses, paginated([ project_status1, project_status2 ]))
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders a list of project_statuses" do
    render
    expect(rendered).to include(project_status1.name, project_status2.name)
  end

  it "renders a friendly message when no project_statuses exist" do
    assign(:project_statuses, paginated([]))
    render
    expect(rendered).to match(/No project statuses found/)
  end
end
