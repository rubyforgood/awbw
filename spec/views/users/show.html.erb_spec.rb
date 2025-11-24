require 'rails_helper'

RSpec.describe "users/show", type: :view do
  let(:user) do
    create(:user,
           first_name: "First Name",
           last_name: "Last Name",
           email: "Email@example.com",
           comment: "MyText",
           notes: "MyText",
           inactive: false,
           super_user: false
    )
  end

  let(:super_user) { create(:user, :admin) }
  let(:windows_type) { create(:windows_type, name: "Adult Windows") }
  let!(:workshop) { create(:workshop, title: "Mindful Art", user: user, windows_type: windows_type) }

  let!(:project) { create(:project, name: "Healing Arts") }
  let!(:project_user) { create(:project_user, project: project, user: user, position: :leader) }

  before do
    assign(:user, user)
    allow(view).to receive(:current_user).and_return(super_user)
  end

  it "renders user attributes" do
    render
    expect(rendered).to include("First Name")
    expect(rendered).to include("Last Name")
  end

  it "renders authored workshops" do
    render
    expect(rendered).to include("Mindful Art")
  end

  it "renders affiliated projects" do
    render
    expect(rendered).to include("Healing Arts")
  end
end
