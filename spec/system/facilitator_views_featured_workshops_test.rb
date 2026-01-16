require 'rails_helper'

RSpec.describe 'Facilitators can bookmark workshops' do
  describe "Facilitator bookmarks a workshop" do
    context "when facilitator is logged in" do
      before do
        user = create(:user)
        create(:facilitator, user: user)
        adult_window = create(:windows_type, :adult)
        create(:workshop, title: 'The best workshop in the world', windows_type: adult_window, featured: true)
        create(:workshop, title: 'The best workshop on mars', windows_type: adult_window, featured: true)
        create(:workshop, title: 'oh hello!', windows_type: adult_window, featured: true)
        create(:workshop, title: 'Advanced Leadership Skills', windows_type: adult_window, featured: true)
        create(:workshop, title: 'Mindfulness Meditation', windows_type: adult_window, featured: true)


        sign_in user
        visit '/'
      end
      def active_slide
        find('.swiper-slide-active')
     end

      it "verifies featured workshops existence" do
        expect(page).to have_content("Featured Workshops")
        expect(page).to have_content("The best workshop in the world")
        expect(page).to have_content("The best workshop on mars")
        expect(page).to have_content("oh hello!")
      end

      it "verifies carousel presence" do
        expect(page).to have_css('[data-controller="carousel"]')
        expect(page).to have_css('.swiper-wrapper')
        expect(page).to have_css('.swiper-button-next-custom')
        expect(page).to have_css('.swiper-button-prev-custom')
      end

      # next btn
      it "tests next button functionality" do
        expect(page).to have_css('.swiper-button-next-custom')

        find('.swiper-button-next-custom').click
        expect(page).to have_content("Advanced Leadership Skills")

        sleep 1
        find('.swiper-button-next-custom').click
        expect(page).to have_content("Mindfulness Meditation")
      end

      # prev btn
      it "tests previous button functionality" do
         expect(page).to have_css('.swiper-button-prev-custom')

         find('.swiper-button-prev-custom').click
         expect(page).to have_content("The best workshop on mars")

         find('.swiper-button-prev-custom').click
         expect(page).to have_content("The best workshop in the world")

         find('.swiper-button-prev-custom').click
         expect(page).to have_content("Mindfulness Meditation")
       end
    end
  end
end
