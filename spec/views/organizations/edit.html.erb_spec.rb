require 'rails_helper'

RSpec.describe "organizations/edit", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:organization_status) { create(:organization_status) }
  let(:windows_type) { create(:windows_type) }

  let(:organization) {
    Organization.create!(
      windows_type: windows_type,
      organization_status: organization_status,
      location: nil,
      name: "MyString",
      description: "MyString",
      notes: "MyText"
    )
  }

  before(:each) do
    assign(:organization, organization)
    allow(view).to receive(:current_user).and_return(admin)
    allow(view).to receive(:allowed_to?).and_return(true)
    render
  end

  it "renders the edit organization form" do
    assert_select "form[action=?][method=?]", organization_path(organization), "post" do
      assert_select "select[name=?]", "organization[windows_type_id]"

      assert_select "textarea[name=?]", "organization[name]"

      assert_select "textarea[name=?]", "organization[description]"

      assert_select "select[name=?]", "organization[organization_status_id]"
    end
  end
end
