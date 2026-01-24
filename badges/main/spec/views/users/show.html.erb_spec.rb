require 'rails_helper'

RSpec.describe "users/show", type: :view do
  let(:user) do
    create(:user,
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
  let!(:project_user) { create(:project_user, project: project, title: "Title", user: user, position: :leader) }

  before do
    assign(:user, user)
    allow(view).to receive(:current_user).and_return(super_user)
  end

  it "renders facilitator attributes" do
    render
    expect(rendered).to include("email@example.com")
  end

  it "renders devise data" do
    render
    expect(rendered).to include("Current sign-in")
  end

  it "renders audit data" do
    render
    expect(rendered).to include(I18n.l(user.updated_at, format: :long))
  end
end
