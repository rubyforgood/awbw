require 'rails_helper'

RSpec.describe "Stories", type: :system do
  describe 'story index' do
    context "When user is logged in" do
      it 'User sees overview of stories' do
        sign_in(create(:user))

        create(:sector, :other)
        adult_window = create(:windows_type, :adult)
        story_world = create(:story, title: 'The best story in the world', windows_type: adult_window, published: true)
        story_mars = create(:story, title: 'The best story on mars', windows_type: adult_window, published: true)
        story_hello = create(:story, title: 'oh hello!', windows_type: adult_window, published: true)

        visit stories_path

        expect(page).to have_content("Stories")
        expect(page).to have_css("turbo-frame#story_results")

        expect(page).to have_content(story_world.title)
        expect(page).to have_content(story_mars.title)
        expect(page).to have_content(story_hello.title)
      end

      it 'User sees message when no stories exist' do
        sign_in(create(:user))

        visit stories_path

        expect(page).to have_content("Stories")
        expect(page).to have_css("turbo-frame#story_results")

        expect(page).to have_content("No stories found")
      end

      it 'User can search for a story' do
        user = create(:user)
        sign_in(user)

        create(:sector, :other)
        adult_window = create(:windows_type, :adult)
        facilitator = create(:facilitator, first_name: "John", last_name: "Doe")
        story_world = create(:story, title: 'The best story in the world', windows_type: adult_window, created_by: facilitator.user, published: true, rhino_body: "healing through art")
        story_mars = create(:story, title: 'The best story on mars', windows_type: adult_window, created_by: facilitator.user, published: true, rhino_body: "healing through art")
        story_hello = create(:story, title: 'oh hello!', windows_type: adult_window, published: true, rhino_body: "healing through art")

        visit stories_path

        expect(page).to have_content(story_world.title)

        fill_in 'title', with: 'best story'
        fill_in 'query', with: 'healing'

        expect(page).to have_content(story_world.title)
        expect(page).to have_content(story_mars.title)
        expect(page).not_to have_content(story_hello.title)
      end
    end
  end

  describe 'view story' do
    context "When user is logged in" do
      it "User sees story details" do
        sign_in(create(:user))

        story = create(:story, title: 'The best story in the world. This is a tribute.')

        visit story_path(story)

        expect(page).to have_content(story.title)
      end
    end
  end

  describe 'edit story' do
    context "When super user is logged in" do
      it "Super user can edit an existing story" do
        user = create(:user, super_user: true)
        sign_in(user)
        adult_window = create(:windows_type, :adult)
        story = create(:story, title: "Old Title", windows_type: adult_window, created_by: user)

        visit edit_story_path(story)

        fill_in "Title", with: "A New Title"
        select adult_window.short_name, from: "Windows type"

        click_on 'Update Story'

        expect(page).to have_content("A New Title")
        expect(page).to have_content("Story was successfully updated.")
      end
    end
  end
end
