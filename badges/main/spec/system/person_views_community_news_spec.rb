require 'rails_helper'

RSpec.describe 'People can view Community News on the dashboard' do
  describe 'Viewing Community News and Events' do
    before do
      page.driver.browser.manage.window.resize_to(1400, 4000)
      user = create(:user)
      create(:person, user: user)

      create(
        :event,
        :featured,
        :published,
        :publicly_visible,
        :publicly_featured,
        title: 'Annual Leadership Summit',
        start_date: 2.weeks.from_now,
        end_date: 3.weeks.from_now,
        description: 'Join us for our annual leadership conference'
      )

      create(
        :community_news,
        :featured,
        :published,
        :publicly_visible,
        :publicly_featured,
        title: 'March Community Newsletter',
        rhino_body: '<p>Exciting updates this month!</p>'
      )

      sign_in user
      visit root_path
    end

    describe 'Upcoming Events section' do
      it 'displays the Upcoming Events section' do
        expect(page).to have_content('Upcoming Events')
      end

      it 'navigates to events page when "View all events" is clicked' do
        expect(page).to have_link('View all events')
        click_link('View all events')

        expect(page).to have_current_path(events_path)
        expect(page).to have_content('Community of Practice Events')
        expect(page).to have_content('Annual Leadership Summit')
      end
    end

    describe 'Community News section' do
      it 'displays the Community News section' do
        expect(page).to have_content('Community News')
      end

      xit 'navigates to community news page when "Read all news" is clicked' do
        expect(page).to have_link('Read all news')
        click_link('Read all news')

        expect(page).to have_current_path(community_news_index_path)
        expect(page).to have_content('Community news')
        expect(page).to have_content('March Community Newsletter')
      end
    end
  end
end
