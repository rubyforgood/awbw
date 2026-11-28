require "rails_helper"

# Same failure mode as Community News: a story with a website_url redirected the
# post-save show page off-site, which Turbo's form fetch can't follow, so the
# editor stayed on the form with no feedback and re-submitted.
RSpec.describe "Story update redirect", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:story) do
    create(:story,
           title: "Original Story",
           rhino_body: "<p>original body</p>",
           website_url: "https://example.com/article")
  end

  scenario "advances to the story after a successful update" do
    sign_in admin
    visit edit_story_path(story)

    fill_in "story_title", with: "Updated Story"
    page.execute_script(
      "document.getElementById('story_rhino_body').value = '<p>updated body</p>'"
    )
    find("button[type=submit], input[type=submit]").click

    expect(page).to have_current_path(%r{/stories/#{story.id}}, wait: 10)
    expect(page).to have_no_field("story_title")
    expect(page).to have_content("Story was successfully updated.")
    expect(page).to have_content("Updated Story")
    expect(Story.count).to eq(1)
  end
end
