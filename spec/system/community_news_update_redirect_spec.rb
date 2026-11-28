require "rails_helper"

# A news post with a reference URL used to send the editor off-site after save:
# the post-save redirect landed on #show, which redirected to the reference URL.
# Turbo can't follow a cross-origin form redirect, so the page stayed on the form
# with no feedback and the editor re-submitted, producing duplicates.
RSpec.describe "Community news update redirect", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:community_news) do
    create(:community_news,
           title: "Original Title",
           rhino_body: "<p>original body</p>",
           reference_url: "https://example.com/article")
  end

  scenario "advances to the post after a successful update" do
    sign_in admin
    visit edit_community_news_path(community_news)

    fill_in "community_news_title", with: "Updated Title"
    # The Rhino editor syncs into a hidden field; set it directly to satisfy
    # the rhino_body presence validation without driving the web component.
    page.execute_script(
      "document.getElementById('community_news_rhino_body').value = '<p>updated body</p>'"
    )
    find("button[type=submit], input[type=submit]").click

    expect(page).to have_current_path(%r{/community_news/#{community_news.id}}, wait: 10)
    expect(page).to have_no_field("community_news_title")
    expect(page).to have_content("Community news was successfully updated.")
    expect(page).to have_content("Updated Title")
    expect(CommunityNews.count).to eq(1)
  end
end
