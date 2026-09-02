require "rails_helper"

RSpec.describe "People index affiliations", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:turbo_headers) { { "Turbo-Frame" => "people_results", "Accept" => "text/html" } }

  before { sign_in admin }

  it "shows one entry per organization, preferring the affiliation with a job title" do
    person = create(:person, first_name: "Dupe")
    org = create(:organization, name: "Shared Org")
    create(:affiliation, person: person, organization: org, title: "Facilitator",
                         start_date: 1.year.ago.to_date)
    create(:affiliation, person: person, organization: org, title: "Counselor",
                         start_date: 1.year.ago.to_date)

    get people_path, headers: turbo_headers

    doc = Capybara.string(response.body)
    expect(doc.all("a[href='#{organization_path(org)}']").size).to eq(1)
    expect(response.body).to include("Counselor")
  end
end
