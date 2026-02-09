require 'rails_helper'

RSpec.describe "organization_statuses/edit", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:organization_status) { create(:organization_status) }

  before(:each) do
    sign_in admin
    assign(:organization_status, organization_status)
  end

  it "renders the edit organization_status form" do
    render

    assert_select "form[action=?][method=?]", organization_status_path(organization_status), "post" do
      assert_select "input[name=?]", "organization_status[name]"
    end
  end
end
