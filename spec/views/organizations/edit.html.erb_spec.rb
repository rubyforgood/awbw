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
  end

  it "renders the edit organization form" do
    render
    assert_select "form[action=?][method=?]", organization_path(organization), "post" do
      assert_select "select[name=?]", "organization[windows_type_id]"

      assert_select "textarea[name=?]", "organization[name]"

      assert_select "textarea[name=?]", "organization[description]"
    end
  end

  describe "status select visibility" do
    before(:each) { assign(:organization_statuses, OrganizationStatus.all) }

    def org_with_status(name)
      Organization.create!(
        windows_type: windows_type,
        organization_status: OrganizationStatus.find_or_create_by!(name: name),
        name: "MyString",
        description: "MyString",
        notes: "MyText"
      )
    end

    it "shows the status select for an org with no affiliations" do
      assign(:organization, org_with_status("Active"))
      render
      assert_select "select[name=?]", "organization[organization_status_id]"
    end

    it "hides the status select (and the mismatch hint) when the status matches the affiliation-calculated status" do
      org = org_with_status("Active")
      create(:affiliation, organization: org, person: create(:person), inactive: false, end_date: nil)
      assign(:organization, org.reload)
      render
      assert_select "select[name=?]", "organization[organization_status_id]", false
      assert_select "input[type=hidden][name=?]", "organization[organization_status_id]"
      expect(rendered).not_to include("Does not match affiliations status")
    end

    it "shows the status select and the red mismatch hint when the status does not match the affiliation-calculated status" do
      org = org_with_status("Pending")
      create(:affiliation, organization: org, person: create(:person), inactive: false, end_date: nil)
      assign(:organization, org.reload)
      render
      assert_select "select[name=?]", "organization[organization_status_id]"
      assert_select "p.text-red-600", text: "Does not match affiliations status"
    end
  end
end
