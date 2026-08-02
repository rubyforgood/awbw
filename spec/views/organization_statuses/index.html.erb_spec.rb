require 'rails_helper'

RSpec.describe "organization_statuses/index", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:organization_status1) { create(:organization_status, name: "Active") }
  let(:organization_status2) { create(:organization_status, name: "Suspended") }

  before(:each) do
    assign(:organization_statuses, paginated([ organization_status1, organization_status2 ]))
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders a list of organization_statuses" do
    render
    expect(rendered).to include(organization_status1.name, organization_status2.name)
  end

  it "renders a friendly message when no organization_statuses exist" do
    assign(:organization_statuses, paginated([]))
    render
    expect(rendered).to match(/No organization statuses found/)
  end
end
