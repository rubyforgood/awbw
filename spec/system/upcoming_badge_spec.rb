require "rails_helper"

RSpec.describe "Upcoming affiliation badge", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:person) { create(:person, user: admin) }
  let!(:org) { create(:organization, name: "Zeta Test Center") }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in admin
  end

  # Maps each row's title to whether its Upcoming badge is hidden, read straight
  # from the live DOM after the inactive-toggle controller has run.
  def badge_hidden_by_title
    page.evaluate_script(<<~JS).to_h { |r| [ r["title"], r["hidden"] ] }
      Array.from(document.querySelectorAll('.nested-fields')).map(function(row){
        var title = row.querySelector("input[name*='title']");
        var badge = row.querySelector("[data-inactive-toggle-target='upcomingBadge']");
        return { title: title ? title.value : null, hidden: badge ? badge.classList.contains('hidden') : null };
      });
    JS
  end

  it "badges Upcoming only for a future start that has not ended" do
    create(:affiliation, person: person, organization: org, title: "PastActive",
                         start_date: 1.year.ago.to_date, end_date: nil)
    create(:affiliation, person: person, organization: org, title: "Ended",
                         start_date: 2.years.ago.to_date, end_date: 1.month.ago.to_date)
    create(:affiliation, person: person, organization: org, title: "FutureUp",
                         start_date: 1.month.from_now.to_date, end_date: nil)
    create(:affiliation, person: person, organization: org, title: "StartsToday",
                         start_date: Date.current, end_date: nil)
    create(:affiliation, person: person, organization: org, title: "StartsTomorrow",
                         start_date: Date.current + 1.day, end_date: nil)

    visit edit_person_path(person)
    expect(page).to have_css(".nested-fields", minimum: 5, wait: 10)

    hidden = badge_hidden_by_title
    expect(hidden["PastActive"]).to be(true)
    expect(hidden["Ended"]).to be(true)
    expect(hidden["StartsToday"]).to be(true)
    expect(hidden["FutureUp"]).to be(false)
    expect(hidden["StartsTomorrow"]).to be(false)
  end
end
