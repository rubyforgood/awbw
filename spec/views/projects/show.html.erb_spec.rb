require "rails_helper"

RSpec.describe "projects/show", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let!(:project) { create(:project, name: "Project 1") }

  before do
    assign(:project, project)
    allow(view).to receive(:current_user).and_return(user)
    render
  end

  it "renders attributes" do
    expect(rendered).to match(project.name)
  end
end
