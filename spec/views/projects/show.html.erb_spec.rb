require "rails_helper"

RSpec.describe "projects/show", type: :view do
  let!(:combined_perm) { create(:permission, :combined) }
  let!(:adult_perm) { create(:permission, :adult) }
  let!(:children_perm) { create(:permission, :children) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let!(:project) { create(:project, name: "Project 1") }

  before do
    assign(:project, project)
    allow(view).to receive(:current_user).and_return(user)
    render
  end

  it "renders attributes" do
    expect(rendered).to match("Project 1")
  end
end
