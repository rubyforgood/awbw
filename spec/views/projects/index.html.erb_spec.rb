require "rails_helper"

RSpec.describe "projects/index", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let!(:project1) { create(:project, name: "Project 1") }
  let!(:project2) { create(:project, name: "Project 2") }

  before(:each) do
    assign(:projects, paginated([project1, project2]))
    assign(:project_statuses, create_list(:project_status, 3))
    allow(view).to receive(:current_user).and_return(user)
    render
  end

  it "renders a list of projects" do
    expect(rendered).to match(project1.name)
    expect(rendered).to match(project2.name)
  end
end
