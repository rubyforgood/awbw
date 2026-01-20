require "rails_helper"

RSpec.describe "organizations/show", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let!(:organization) { create(:organization, name: "Organization 1") }

  before do
    assign(:organization, organization)
    allow(view).to receive(:current_user).and_return(user)
    render
  end

  it "renders attributes" do
    expect(rendered).to match(organization.name)
  end
end
