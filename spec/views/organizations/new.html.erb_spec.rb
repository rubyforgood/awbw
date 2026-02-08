require 'rails_helper'

RSpec.describe "organizations/new", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  before do
    assign(:organization, Organization.new)
    allow(view).to receive(:current_user).and_return(admin)
    render
  end

  it "renders new organization form" do
    assert_select "form[action=?][method=?]", organizations_path, "post" do
      assert_select "select[name=?]", "organization[windows_type_id]"

      assert_select "textarea[name=?]", "organization[name]"

      assert_select "textarea[name=?]", "organization[description]"

      assert_select "select[name=?]", "organization[organization_status_id]"

      assert_select "input[name=?]", "organization[inactive]"

      assert_select "textarea[name=?]", "organization[notes]"
    end
  end
end
