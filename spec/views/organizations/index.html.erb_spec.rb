require "rails_helper"

RSpec.describe "organizations/index", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let!(:organization1) { create(:organization, name: "Organization 1") }
  let!(:organization2) { create(:organization, name: "Organization 2") }

  let!(:organization_status1) { create(:organization_status, name: "Active") }
  let!(:organization_status2) { create(:organization_status, name: "Formerly active") }
  let!(:organization_status3) { create(:organization_status, name: "Unknown") }

  before(:each) do
    assign(:organizations, paginated([ organization1, organization2 ]))
    assign(:organization_statuses, [ organization_status1, organization_status2, organization_status3 ])
    assign(:affiliated_since_display, {})
    assign(:active_people_counts, {})
    assign(:active_people_count, 0)
    assign(:organizations_count, 2)
    allow(view).to receive(:current_user).and_return(user)
  end

  it "renders the skeleton loader" do
    render
    expect(rendered).to have_css("turbo-frame#organizations_results")
  end

  it "renders a list of organizations" do
    render template: "organizations/organizations_results"
    expect(rendered).to match(organization1.name)
    expect(rendered).to match(organization2.name)
  end
end
