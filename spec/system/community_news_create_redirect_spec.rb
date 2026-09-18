require "rails_helper"

# Experiment: does a successful create advance the page under Turbo?
# The PR premise is that without `status: :see_other` the create redirect (302)
# leaves the user on the form, so re-submitting produces duplicate records.
RSpec.describe "Community news create redirect", type: :system do
  let(:admin) { create(:user, :admin) }

  def fill_and_submit
    fill_in "community_news_title", with: "Redirect Experiment"
    # The Rhino editor syncs into a hidden field; set it directly to satisfy
    # the rhino_body presence validation without driving the web component.
    page.execute_script(
      "document.getElementById('community_news_rhino_body').value = '<p>experiment body</p>'"
    )
    find("button[type=submit], input[type=submit]").click
  end

  scenario "advances to the show page after a successful create" do
    sign_in admin
    visit new_community_news_path

    fill_and_submit

    # Advanced away from the form to a show page, and no duplicate created.
    expect(page).to have_current_path(%r{/community_news/\d+\z}, wait: 10)
    expect(page).to have_no_field("community_news_title")
    expect(CommunityNews.count).to eq(1)
  end
end
