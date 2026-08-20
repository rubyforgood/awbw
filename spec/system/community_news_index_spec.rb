require "rails_helper"

RSpec.describe "Community News Index", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:community_news) { create(:community_news, :published, title: "Test Community News", rhino_body: "Test content") }

  scenario "Admin visits community news index and sees results load in turbo frame" do
    community_news  # This ensures the record is created

    sign_in admin

    visit community_news_index_path

    expect(page).to have_content("News")
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

    # Click "Title" — first click on an inactive column sorts descending
    click_link "Title"

    # Arrow should show down (desc)
    within("thead") do
      title_header = find("th", text: "Title")
      expect(title_header).to have_css("i.fa-arrow-down")
    end

    # Banana should appear before Apple in descending order
    rows = all("tbody tr td:first-child").map(&:text)
    banana_index = rows.index { |t| t.include?("Banana News") }
    apple_index = rows.index { |t| t.include?("Apple News") }
    expect(banana_index).to be < apple_index
  end

  scenario "Admin toggles title sort direction across multiple clicks" do
    create(:community_news, :published, title: "Banana News", rhino_body: "content")
    create(:community_news, :published, title: "Apple News", rhino_body: "content")

    sign_in admin
    visit community_news_index_path

    # Wait for turbo frame to load
    expect(page).to have_content("Banana News")

    # First click: sort descending (Z-A) — first click on inactive column defaults to desc
    click_link "Title"

    within("thead") do
      expect(find("th", text: "Title")).to have_css("i.fa-arrow-down")
    end

    rows = all("tbody tr td:first-child").map(&:text)
    expect(rows.index { |t| t.include?("Banana News") }).to be < rows.index { |t| t.include?("Apple News") }

    # Second click: sort ascending (A-Z)
    click_link "Title"

    within("thead") do
      expect(find("th", text: "Title")).to have_css("i.fa-arrow-up")
    end

    rows = all("tbody tr td:first-child").map(&:text)
    expect(rows.index { |t| t.include?("Apple News") }).to be < rows.index { |t| t.include?("Banana News") }

    # Third click: back to descending (Z-A)
    click_link "Title"

    within("thead") do
      expect(find("th", text: "Title")).to have_css("i.fa-arrow-down")
    end

    rows = all("tbody tr td:first-child").map(&:text)
    expect(rows.index { |t| t.include?("Banana News") }).to be < rows.index { |t| t.include?("Apple News") }
  end

  scenario "Admin clears text filters and sees all results again" do
    create(:community_news, :published, title: "Banana News", rhino_body: "content")
    create(:community_news, :published, title: "Apple News", rhino_body: "content")

    sign_in admin
    visit community_news_index_path

    # Wait for turbo frame to load both results
    expect(page).to have_content("Banana News")
    expect(page).to have_content("Apple News")

    # Filter by title to narrow results
    fill_in "title", with: "Banana"

    expect(page).to have_content("Banana News")
    expect(page).not_to have_content("Apple News")

    # Click "Clear filters" to reset
    click_link "Clear filters"

    # Both results should reappear
    expect(page).to have_content("Banana News")
    expect(page).to have_content("Apple News")

    # Text field should be empty
    expect(find_field("title").value).to eq("")
  end

  scenario "Admin clears multiple text filters and sees all results again" do
    create(:community_news, :published, title: "Banana News", rhino_body: "tropical fruit")
    create(:community_news, :published, title: "Apple News", rhino_body: "temperate fruit")

    sign_in admin
    visit community_news_index_path

    # Wait for turbo frame to load both results
    expect(page).to have_content("Banana News")
    expect(page).to have_content("Apple News")

    # Filter by title and keyword to narrow results
    fill_in "title", with: "Banana"
    fill_in "query", with: "tropical"

    expect(page).to have_content("Banana News")
    expect(page).not_to have_content("Apple News")

    # Click "Clear filters" to reset
    click_link "Clear filters"

    # Both results should reappear
    expect(page).to have_content("Banana News")
    expect(page).to have_content("Apple News")

    # Both text fields should be empty
    expect(find_field("title").value).to eq("")
    expect(find_field("query").value).to eq("")
  end

  # Arriving with the filters already in the URL (a shared link, a drill-in) is the
  # case where the server renders them as value/selected attributes — so clearing
  # has to beat the browser's notion of the form's defaults, not just the fields'
  # current state.
  scenario "Admin clears filters that arrived in the URL" do
    org = create(:organization, name: "Banana Org")
    create(:community_news, :published, title: "Banana News", rhino_body: "content", organization: org)
    create(:community_news, :published, title: "Apple News", rhino_body: "content")

    sign_in admin
    visit community_news_index_path(title: "Banana", organization_id: org.id)

    expect(page).to have_content("Banana News")
    expect(page).not_to have_content("Apple News")

    click_link "Clear filters"

    expect(page).to have_content("Banana News")
    expect(page).to have_content("Apple News")
    expect(find_field("title").value).to eq("")
    expect(find_field("organization_id").value).to eq("")
  end

  scenario "Admin sees message when no community news exist" do
    sign_in admin

    visit community_news_index_path

    expect(page).to have_content("No community news yet")
    expect(page).to have_content("Create a community news")
  end
end
