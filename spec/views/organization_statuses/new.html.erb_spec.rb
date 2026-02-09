require 'rails_helper'

RSpec.describe "organization_statuses/new", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:organization_status) { build(:organization_status) }

  before do
    allow(view).to receive(:current_user).and_return(admin)
    assign(:organization_status, organization_status)
  end

  it "renders new organization_status form" do
    render

    assert_select "form[action=?]", organization_statuses_path do
      assert_select "input[name=?]", "organization_status[name]"
    end
  end
end
