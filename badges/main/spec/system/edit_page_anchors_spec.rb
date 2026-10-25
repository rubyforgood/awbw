require "rails_helper"

RSpec.describe "In-page links on the organization and person edit pages", type: :system do
  let(:organization) { create(:organization) }

  before do
    driven_by(:selenium_chrome_headless)
    create(:address, addressable: organization, phone: "555-010-0000")
    create(:address, addressable: organization, phone: "555-020-0000")
    sign_in create(:user, :admin)
  end

  it "jumps from the phones note to the addresses, clear of the sticky header" do
    visit edit_organization_path(organization)
    page.driver.browser.manage.window.resize_to(1440, 900)
    expect(page).to have_css("[data-affiliation-dates-ready]", wait: 10)

    click_link "address number"

    expect(page).to have_current_path(/#addresses\z/, url: true)
    expect(addresses_heading_in_view?).to be(true)
  end

  it "lands a person edit #addresses link clear of the sticky header" do
    person = create(:person)
    create(:address, addressable: person, phone: "555-030-0000")

    visit edit_person_path(person, anchor: "addresses")
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit edit_person_path(person, anchor: "addresses")

    expect(addresses_heading_in_view?).to be(true)
  end

  # The sticky page header ends with the page title, so the heading must clear it.
  def addresses_heading_in_view?
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        visible = page.evaluate_script(<<~JS)
          (() => {
            const top = document.querySelector("#addresses h3").getBoundingClientRect().top;
            const headerBottom = document.querySelector("h1").getBoundingClientRect().bottom;
            return top >= headerBottom && top < window.innerHeight;
          })()
        JS
        break true if visible
        sleep 0.1
      end
    end
  rescue Timeout::Error
    false
  end
end
