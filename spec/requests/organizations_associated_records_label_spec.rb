require "rails_helper"

RSpec.describe "Organization associated records label", type: :request do
  let(:organization) { create(:organization) }

  def associated_records_header
    Capybara.string(response.body).find("h2", text: "Associated records").find(:xpath, "..")
  end

  it "tells a member that admins and other members can see it" do
    member = create(:user, :with_person)
    create(:affiliation, person: member.person, organization: organization, start_date: 1.year.ago.to_date)
    sign_in member
    get organization_path(organization)

    expect(associated_records_header).to have_text("Only visible to members and admins")
  end

  it "shows the same label to an admin" do
    sign_in create(:user, :admin)
    get organization_path(organization)

    expect(associated_records_header).to have_text("Only visible to members and admins")
  end
end
