require 'rails_helper'

RSpec.describe "projects/index", type: :view do
  let!(:combined_perm) { create(:permission, :combined) }
  let!(:adult_perm)    { create(:permission, :adult) }
  let!(:children_perm) { create(:permission, :children) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:project1) { create(:project)}
  let(:project2) { create(:project)}

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
