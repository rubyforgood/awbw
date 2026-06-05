require "rails_helper"

RSpec.describe "Story gallery lightbox", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "opens additional images inline and scrolls through them" do
    sign_in create(:user)

    story = create(:story, :published, title: "A story with extra images")
    create(:gallery_asset, :with_file, owner: story)
    create(:gallery_asset, :with_file, owner: story)

    visit story_path(story)

    expect(page).to have_css("[data-controller='lightbox']")
    expect(page).to have_css("[data-lightbox-target='item']", count: 2)

    # Modal starts hidden
    modal = find("[data-lightbox-target='modal']", visible: :all)
    expect(modal[:class]).to include("hidden")

    # Clicking an additional image opens it inline rather than navigating away
    all("[data-lightbox-target='item']").first.click

    expect(page).to have_current_path(story_path(story))
    expect(modal[:class]).not_to include("hidden")
    expect(page).to have_css("[data-lightbox-target='counter']", text: "1 of 2")

    # Next/previous controls scroll through the set
    find("[data-lightbox-target='next']").click
    expect(page).to have_css("[data-lightbox-target='counter']", text: "2 of 2")

    find("[data-lightbox-target='prev']").click
    expect(page).to have_css("[data-lightbox-target='counter']", text: "1 of 2")

    # Closing dismisses the modal
    find("[data-action='lightbox#close']").click
    expect(modal[:class]).to include("hidden")
  end
end
