require "rails_helper"

RSpec.describe "Community News Index", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:community_news) { create(:community_news, :published, title: "Test Community News", rhino_body: "Test content") }

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

  scenario "Admin sorts by title and sees the correct arrow icon" do
    create(:community_news, :published, title: "Banana News", rhino_body: "content")
    create(:community_news, :published, title: "Apple News", rhino_body: "content")

    sign_in admin
    visit community_news_index_path

    # Wait for turbo frame to load
    expect(page).to have_content("Banana News")

    # Click "Title" to sort ascending
    click_link "Title"

    # Arrow should switch to up (asc)
    within("thead") do
      title_header = find("th", text: "Title")
      expect(title_header).to have_css("i.fa-arrow-up")
    end

    # Apple should appear before Banana in ascending order
    rows = all("tbody tr td:first-child").map(&:text)
    apple_index = rows.index { |t| t.include?("Apple News") }
    banana_index = rows.index { |t| t.include?("Banana News") }
    expect(apple_index).to be < banana_index
  end

  scenario "Admin toggles title sort direction across multiple clicks" do
    create(:community_news, :published, title: "Banana News", rhino_body: "content")
    create(:community_news, :published, title: "Apple News", rhino_body: "content")

    sign_in admin
    visit community_news_index_path

    # Wait for turbo frame to load
    expect(page).to have_content("Banana News")

    # First click: sort ascending (A-Z)
    click_link "Title"

    within("thead") do
      expect(find("th", text: "Title")).to have_css("i.fa-arrow-up")
    end

    rows = all("tbody tr td:first-child").map(&:text)
    expect(rows.index { |t| t.include?("Apple News") }).to be < rows.index { |t| t.include?("Banana News") }

    # Second click: sort descending (Z-A)
    click_link "Title"

    within("thead") do
      expect(find("th", text: "Title")).to have_css("i.fa-arrow-down")
    end

    rows = all("tbody tr td:first-child").map(&:text)
    expect(rows.index { |t| t.include?("Banana News") }).to be < rows.index { |t| t.include?("Apple News") }

    # Third click: back to ascending (A-Z)
    click_link "Title"

    within("thead") do
      expect(find("th", text: "Title")).to have_css("i.fa-arrow-up")
    end

    rows = all("tbody tr td:first-child").map(&:text)
    expect(rows.index { |t| t.include?("Apple News") }).to be < rows.index { |t| t.include?("Banana News") }
  end

  scenario "Admin sees message when no community news exist" do
    sign_in admin

    visit community_news_index_path

    expect(page).to have_content("No community news yet")
    expect(page).to have_content("Create a community news")
  end
end
