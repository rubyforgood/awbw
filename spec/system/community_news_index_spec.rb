require "rails_helper"

RSpec.describe "Community News Index", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:community_news) { create(:community_news, title: "Test Community News", published: true, rhino_body: "Test content") }

  scenario "Admin visits community news index and sees results load in turbo frame" do
    community_news  # This ensures the record is created

    sign_in admin

    visit community_news_index_path

    expect(page).to have_content("Community news")
    expect(page).to have_css("turbo-frame#community_news_results")
    expect(page).to have_css("turbo-frame[src]")

    # Wait for turbo frame to load and show actual results
    expect(page).to have_content("Test Community News")
  end

  scenario "Admin sees message when no community news exist" do
    sign_in admin

    visit community_news_index_path

    expect(page).to have_content("No community news yet")
    expect(page).to have_content("Create a post")
  end
end
