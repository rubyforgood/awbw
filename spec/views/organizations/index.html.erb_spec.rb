require "rails_helper"

RSpec.describe "organizations/index", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let!(:organization1) { create(:organization, name: "Organization 1") }
  let!(:organization2) { create(:organization, name: "Organization 2") }

  let!(:organization_status1) { create(:organization_status, name: "Active") }
  let!(:organization_status2) { create(:organization_status, name: "Suspended") }
  let!(:organization_status3) { create(:organization_status, name: "Inactive") }

  before(:each) do
    assign(:organizations, paginated([ organization1, organization2 ]))
    assign(:organization_statuses, [ organization_status1, organization_status2, organization_status3 ])
    allow(view).to receive(:current_user).and_return(user)
    render
  end

  it "renders a list of organizations" do
    expect(rendered).to match(organization1.name)
    expect(rendered).to match(organization2.name)
  end
end
