require "rails_helper"

# The server-rendered half of the affiliation editor's status badges. The live
# half (badges following the start date as it's edited) is spec/system/upcoming_badge_spec.rb.
RSpec.describe "Affiliation status badges on the person edit form", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let(:org) { create(:organization) }

  before { sign_in admin }

  # Each row's title paired with which of its two badges rendered visible.
  def shown_badges_by_title
    Capybara.string(response.body).all(".nested-fields").to_h do |row|
      shown = %w[ inactiveBadge upcomingBadge ].select do |target|
        badge = row.first("[data-inactive-toggle-target='#{target}']", minimum: 0)
        badge && !badge[:class].split.include?("hidden")
      end
      [ row.first("input[name*='title']")[:value], shown ]
    end
  end

  it "renders Inactive for not-active rows and adds Upcoming for a future start" do
    create(:affiliation, person: person, organization: org, title: "PastActive",
                         start_date: 1.year.ago.to_date, end_date: nil)
    create(:affiliation, person: person, organization: org, title: "Ended",
                         start_date: 2.years.ago.to_date, end_date: 1.month.ago.to_date)
    create(:affiliation, person: person, organization: org, title: "FutureUp",
                         start_date: 1.month.from_now.to_date, end_date: nil)
    create(:affiliation, person: person, organization: org, title: "StartsToday",
                         start_date: Date.current, end_date: nil)

    get edit_person_path(person)

    expect(shown_badges_by_title).to eq(
      "PastActive" => [],
      "StartsToday" => [],
      "Ended" => [ "inactiveBadge" ],
      "FutureUp" => [ "inactiveBadge", "upcomingBadge" ]
    )
  end
end
