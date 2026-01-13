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
        visit events_path

        # Register for the event
        within("#card_event_#{@event.id}") do
          click_button 'Register'
        end
      end

      describe "Calendar links after registration" do
        let(:title_encoded) { ERB::Util.url_encode(@event.title) }
        let(:start_time) { @event.start_date.strftime("%Y%m%dT%H%M%SZ") }
        let(:end_time) { @event.end_date.strftime("%Y%m%dT%H%M%SZ") }

        before do
          visit events_path
        end

        it "shows calendar options" do
          within("#card_event_#{@event.id}") do
            expect(page).to have_link("Google")
            apple_link = find('a', text: "Apple")
            expect(apple_link[:download]).to end_with(".ics")
            expect(page).to have_link("Office 365")
            expect(page).to have_link("Yahoo")
            expect(page).to have_link("Outlook")
          end
        end

        it "provides Google Calendar link" do
          google_link = find_link("Google")
          expect(google_link[:href]).to include("https://calendar.google.com/calendar/render")
          expect(google_link[:href]).to include("action=TEMPLATE")
          expect(google_link[:href]).to include("text=#{title_encoded}")
          expect(google_link[:href]).to include("dates=#{start_time}/#{end_time}")
        end

        it "provides Outlook link" do
          outlook_link = find_link("Outlook")
          expect(outlook_link[:href]).to include("https://outlook.live.com/owa/")
          expect(outlook_link[:href]).to include("subject=#{title_encoded}")
          expect(outlook_link[:href]).to include("startdt=#{start_time}")
          expect(outlook_link[:href]).to include("enddt=#{end_time}")
        end

        it "provides Office 365 link" do
          office_link = find_link("Office 365")
          expect(office_link[:href]).to include("https://outlook.office.com/owa/")
          expect(office_link[:href]).to include("subject=#{title_encoded}")
          expect(office_link[:href]).to include("startdt=#{start_time}")
          expect(office_link[:href]).to include("enddt=#{end_time}")
        end

        it "provides Yahoo Calendar link" do
          yahoo_link = find_link("Yahoo")
          expect(yahoo_link[:href]).to include("https://calendar.yahoo.com/")
          expect(yahoo_link[:href]).to include("title=#{title_encoded}")
          expect(yahoo_link[:href]).to include("st=#{start_time}")
          expect(yahoo_link[:href]).to include("et=#{end_time}")
        end

        it "provides Apple Calendar .ics download" do
          apple_link = find_link("Apple")
          encoded_ical = apple_link[:href].split(',', 2)[1]
          ical_content = URI.decode_www_form_component(encoded_ical)
          expect(apple_link[:href]).to include("data:text/calendar;charset=utf8,")
          expect(apple_link[:href]).to include("SUMMARY:#{@event.title}")
          expect(apple_link[:href]).to include("DTSTART:#{start_time}")
          expect(apple_link[:href]).to include("DTEND:#{end_time}")
          expect(apple_link[:download]).to be_present
        end

        it "shows registered status and de-register button" do
          within("#card_event_#{@event.id}") do
            expect(page).to have_css("span.text-xs.bg-green-100.text-green-700.px-2.py-0\\.5.rounded-full",
                                     text: "Registered")
            expect(page).to have_button("De-register")
            expect(page).to have_no_button("Register")
          end
        end
      end
    end
  end
end
