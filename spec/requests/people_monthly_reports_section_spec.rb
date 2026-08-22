require "rails_helper"

RSpec.describe "Person profile monthly reports section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:outsider) { create(:user) }

  def get_monthly_reports_section
    get person_path(person, section: "monthly_reports"),
        headers: { "Turbo-Frame" => "person_monthly_reports_section" }
  end

  it "lists an unauthored report the person's user created (legacy fallback)" do
    sign_in owner_user
    report = create(:monthly_report, created_by: owner_user, author: nil)

    get_monthly_reports_section

    expect(response).to be_successful
    expect(response.body).to include(monthly_report_path(report))
  end

  it "lists a report the person explicitly authored" do
    sign_in admin
    report = create(:monthly_report, created_by: create(:user), author: person)

    get_monthly_reports_section

    expect(response.body).to include(monthly_report_path(report))
  end

  it "excludes a report created by their user but authored by someone else" do
    sign_in owner_user
    report = create(:monthly_report, created_by: owner_user, author: create(:person))

    get_monthly_reports_section

    expect(response.body).not_to include(monthly_report_path(report))
  end

  it "denies the section to a non-owner" do
    sign_in outsider
    create(:monthly_report, created_by: owner_user)

    get_monthly_reports_section

    expect(response).to redirect_to(root_path)
  end
end
