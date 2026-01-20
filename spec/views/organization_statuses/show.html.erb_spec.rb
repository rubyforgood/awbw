require 'rails_helper'

RSpec.describe "organization_statuses/show", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:organization_status) { create(:organization_status, name: "Name") }

  before(:each) do
    assign(:organization_status, organization_status)
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
  end
end
