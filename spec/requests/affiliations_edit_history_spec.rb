require "rails_helper"

RSpec.describe "the affiliation edit History section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  # Midday rather than midnight: an event stored at UTC midnight reads as the
  # previous day for a Pacific viewer, and the controller sets the zone per user.
  let(:event) do
    create(:event, facilitator_training: true, title: "TOS205 Fresno",
                   start_date: Time.zone.parse("2026-03-04 12:00"),
                   end_date: Time.zone.parse("2026-03-05 17:00"),
                   registration_close_date: Time.zone.parse("2026-03-01 12:00"))
  end
  let(:registration) { create(:event_registration, event: event, registrant: person, status: "no_show") }
  let(:affiliation) do
    create(:affiliation, person: person, organization: organization, title: "Facilitator",
                         start_date: Date.new(2026, 3, 4), event_registration: registration)
  end

  before do
    sign_in admin
    create(:event_registration_organization, event_registration: registration, organization: organization)
  end

  it "shows the minting training with its event name and date, marked as the source" do
    get edit_affiliation_path(affiliation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("TOS205 Fresno")
    expect(response.body).to include("Mar 4, 2026")
    expect(response.body).to include("Created this affiliation")
  end

  it "lays the entries out in Change / What / When / By columns" do
    get edit_affiliation_path(affiliation)

    headers = Nokogiri::HTML(response.body).css("li.contents").first.css("span").map(&:text).map(&:strip)
    expect(headers).to eq(%w[Change What When By])
  end

  it "renders a recorded edit as before → after, with dates and booleans humanized" do
    Ahoy::Event.create!(name: "update.affiliation", time: 2.days.ago, visit: create(:ahoy_visit),
                        resource_type: "Affiliation", resource_id: affiliation.id, user: admin,
                        properties: { "changes" => {
                          "inactive" => { "before" => false, "after" => true },
                          "end_date" => { "before" => nil, "after" => "2026-03-04" }
                        } })

    get edit_affiliation_path(affiliation)

    expect(response.body).to include("End date")
    expect(response.body).to include("Mar 4, 2026")
    expect(response.body).to include("Yes")
    expect(response.body).to include(admin.full_name)
  end

  it "does not show the section to a non-admin" do
    sign_in create(:user)

    get edit_affiliation_path(affiliation)

    expect(response.body).not_to include("Created this affiliation")
  end
end
