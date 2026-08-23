require "rails_helper"

RSpec.describe "Affiliation status badges", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:person) { create(:person, user: admin) }
  let!(:org) { create(:organization, name: "Zeta Test Center") }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in admin
  end

  # Maps each row's title to whether its Inactive/Upcoming badges are hidden,
  # read straight from the live DOM after the inactive-toggle controller has run.
  def badges_by_title
    page.evaluate_script(<<~JS).to_h { |r| [ r["title"], r ] }
      Array.from(document.querySelectorAll('.nested-fields')).map(function(row){
        var title = row.querySelector("input[name*='title']");
        var inactive = row.querySelector("[data-inactive-toggle-target='inactiveBadge']");
        var upcoming = row.querySelector("[data-inactive-toggle-target='upcomingBadge']");
        return {
          title: title ? title.value : null,
          inactiveHidden: inactive ? inactive.classList.contains('hidden') : null,
          upcomingHidden: upcoming ? upcoming.classList.contains('hidden') : null
        };
      });
    JS
  end

  it "shows Inactive for not-active rows and adds Upcoming for future starts" do
    create(:affiliation, person: person, organization: org, title: "PastActive",
                         start_date: 1.year.ago.to_date, end_date: nil)
    create(:affiliation, person: person, organization: org, title: "Ended",
                         start_date: 2.years.ago.to_date, end_date: 1.month.ago.to_date)
    create(:affiliation, person: person, organization: org, title: "FutureUp",
                         start_date: 1.month.from_now.to_date, end_date: nil)
    create(:affiliation, person: person, organization: org, title: "StartsToday",
                         start_date: Date.current, end_date: nil)

    visit edit_person_path(person)
    expect(page).to have_css(".nested-fields", minimum: 4, wait: 10)
    rows = badges_by_title

    # Active now → no badges.
    expect(rows["PastActive"]).to include("inactiveHidden" => true, "upcomingHidden" => true)
    expect(rows["StartsToday"]).to include("inactiveHidden" => true, "upcomingHidden" => true)
    # Ended → Inactive only.
    expect(rows["Ended"]).to include("inactiveHidden" => false, "upcomingHidden" => true)
    # Future start → Inactive AND Upcoming.
    expect(rows["FutureUp"]).to include("inactiveHidden" => false, "upcomingHidden" => false)
  end
end
