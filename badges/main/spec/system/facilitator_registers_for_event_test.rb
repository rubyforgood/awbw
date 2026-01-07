require 'rails_helper'

RSpec.describe "Facilitators can register for an event" do
  describe "Facilitators signs in, views the events and register for the events" do
    context "When Facilitator is logged in" do
      before do
        user = create(:user)
        create(:facilitator, user: user)

        @event = create(:event,
          title: "Upcoming Workshop",
          start_date: 1.day.from_now,
          end_date: 2.days.from_now,
          registration_close_date: 1.day.from_now,
          publicly_visible: true,
          featured: true
        )
        create(:event,
        title: "Another Event",
        start_date: 2.days.from_now,
        end_date: 3.days.from_now,
        registration_close_date: 1.day.from_now,
        publicly_visible: true,
        featured: true,
        created_by: user
      )

        sign_in user
        visit '/'
      end

      # dashboard registration
      it "Register for events from dashboard" do
        within("#card_event_#{@event.id}") do
         expect(page).to have_button("Register")
         click_button 'Register'
       end

        within("#card_event_#{@event.id}") do
          expect(page).to have_css("span.text-xs.bg-green-100.text-green-700.px-2.py-0\\.5.rounded-full",
                                   text: "Registered")
          expect(page).to have_button("De-register")
          expect(page).to have_no_button("Register")
          expect(page).to have_link("Google")
          apple_link = find('a', text: "Apple")
          expect(apple_link[:download]).to end_with(".ics")
          expect(page).to have_link("Office 365")
          expect(page).to have_link("Yahoo")

          accept_confirm do
            click_button "De-register"
          end
          expect(page).to have_button("Register")
          expect(page).to have_no_content("Registered")
        end
      end

      it "navigates to events via community" do
       expect(page).to have_button("Community")
       click_button 'Community'
       within('#community_menu') do
         click_link 'Events'
       end
       expect(page).to have_current_path(events_path)
     end

      it "navigate to events page" do
        expect(page).to have_content("Upcoming Events")

        # events
        expect(page).to have_content("Upcoming Workshop")
        expect(page).to have_content("Another Event")

        expect(page).to have_link("View all events")
        click_link "View all events"
        expect(page).to have_current_path(events_path)
      end

      it "Register for the event" do
        visit events_path

        within("#card_event_#{@event.id}") do
          expect(page).to have_button("Register")
          click_button 'Register'
        end

        within("#card_event_#{@event.id}") do
          expect(page).to have_css("span.text-xs.bg-green-100.text-green-700.px-2.py-0\\.5.rounded-full",
                                   text: "Registered")
          expect(page).to have_button("De-register")
          expect(page).to have_no_button("Register")
          expect(page).to have_link("Google")
          apple_link = find('a', text: "Apple")
          expect(apple_link[:download]).to end_with(".ics")
          expect(page).to have_link("Office 365")
          expect(page).to have_link("Yahoo")

          # de-register
          accept_confirm do
            click_button "De-register"
          end
          expect(page).to have_button("Register")
          expect(page).to have_no_content("Registered")
        end
      end
    end
  end
end
