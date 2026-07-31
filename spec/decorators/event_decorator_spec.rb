require 'rails_helper'

RSpec.describe EventDecorator do
  describe "#videoconference_domain" do
    it "extracts domain name from URL" do
      event = build(:event, videoconference_url: "https://www.zoom.us/j/123").decorate
      expect(event.videoconference_domain).to eq("Zoom")
    end

    it "handles URLs without www" do
      event = build(:event, videoconference_url: "https://meet.google.com/abc").decorate
      expect(event.videoconference_domain).to eq("Google")
    end

    it "uses the second-to-last label, ignoring other subdomains" do
      event = build(:event, videoconference_url: "https://abc.meet.com/x").decorate
      expect(event.videoconference_domain).to eq("Meet")
    end

    it "returns 'video call' for invalid URLs" do
      event = build(:event, videoconference_url: "not a url").decorate
      expect(event.videoconference_domain).to eq("video call")
    end
  end

  describe "#compact_label" do
    it "returns the abbreviation when present" do
      event = build(:event, title: "Trauma-Informed Onsite", abbreviation: "TOS205").decorate
      expect(event.compact_label).to eq("TOS205")
    end

    it "falls back to the full title when abbreviation is blank" do
      event = build(:event, title: "Trauma-Informed Onsite", abbreviation: "").decorate
      expect(event.compact_label).to eq("Trauma-Informed Onsite")
    end
  end

  describe "#videoconference_room" do
    it "pulls the Zoom meeting ID from the join URL and groups the digits" do
      event = build(:event, videoconference_url: "https://awbw-org.zoom.us/j/88285411273").decorate
      expect(event.videoconference_room).to eq({ label: "Meeting ID", value: "882 8541 1273" })
    end

    it "ignores a Zoom pwd query param" do
      event = build(:event, videoconference_url: "https://us02web.zoom.us/j/1234567890?pwd=abc123").decorate
      expect(event.videoconference_room).to eq({ label: "Meeting ID", value: "123 456 7890" })
    end

    it "pulls the meeting code from a Google Meet URL" do
      event = build(:event, videoconference_url: "https://meet.google.com/abc-defg-hij").decorate
      expect(event.videoconference_room).to eq({ label: "Meeting code", value: "abc-defg-hij" })
    end

    it "returns nil for an unrecognized platform" do
      event = build(:event, videoconference_url: "https://example.com/room/42").decorate
      expect(event.videoconference_room).to be_nil
    end

    it "returns nil when there is no URL" do
      event = build(:event, videoconference_url: nil).decorate
      expect(event.videoconference_room).to be_nil
    end

    it "returns nil for an invalid URL" do
      event = build(:event, videoconference_url: "not a url").decorate
      expect(event.videoconference_room).to be_nil
    end
  end

  describe "#multi_day?" do
    it "is true when start and end fall on different days" do
      event = build(:event, start_date: Time.zone.local(2026, 7, 23, 9), end_date: Time.zone.local(2026, 7, 24, 16)).decorate
      expect(event.multi_day?).to be(true)
    end

    it "is false for a same-day event" do
      event = build(:event, start_date: Time.zone.local(2026, 8, 12, 9), end_date: Time.zone.local(2026, 8, 12, 12)).decorate
      expect(event.multi_day?).to be(false)
    end

    it "is false when there is no end date" do
      event = build(:event, start_date: Time.zone.local(2026, 8, 12, 9), end_date: nil).decorate
      expect(event.multi_day?).to be(false)
    end
  end

  describe "#date_range" do
    it "shows a single weekday-prefixed date when there is no end date" do
      event = build(:event, start_date: Time.zone.local(2026, 6, 11, 12), end_date: nil).decorate
      expect(event.date_range).to eq("Thu, Jun 11, 2026")
    end

    it "shows a single date when start and end fall on the same day" do
      event = build(:event, start_date: Time.zone.local(2026, 6, 11, 9), end_date: Time.zone.local(2026, 6, 11, 17)).decorate
      expect(event.date_range).to eq("Thu, Jun 11, 2026")
    end

    it "collapses month and year for a same-month range" do
      event = build(:event, start_date: Time.zone.local(2026, 6, 11, 9), end_date: Time.zone.local(2026, 6, 13, 17)).decorate
      expect(event.date_range).to eq("Thu-Sat, Jun 11-13, 2026")
    end

    it "collapses only the year for a same-year, cross-month range" do
      event = build(:event, start_date: Time.zone.local(2026, 6, 30, 9), end_date: Time.zone.local(2026, 7, 2, 17)).decorate
      expect(event.date_range).to eq("Tue, Jun 30 - Thu, Jul 2, 2026")
    end

    it "shows both years for a cross-year range" do
      event = build(:event, start_date: Time.zone.local(2025, 12, 31, 9), end_date: Time.zone.local(2026, 1, 2, 17)).decorate
      expect(event.date_range).to eq("Wed, Dec 31, 2025 - Fri, Jan 2, 2026")
    end
  end

  describe "#short_date_range" do
    it "shows a single date without a weekday when there is no end date" do
      event = build(:event, start_date: Time.zone.local(2026, 6, 11, 12), end_date: nil).decorate
      expect(event.short_date_range).to eq("Jun 11, 2026")
    end

    it "shows a single date when start and end fall on the same day" do
      event = build(:event, start_date: Time.zone.local(2026, 6, 11, 9), end_date: Time.zone.local(2026, 6, 11, 17)).decorate
      expect(event.short_date_range).to eq("Jun 11, 2026")
    end

    it "collapses month and year for a same-month range" do
      event = build(:event, start_date: Time.zone.local(2026, 9, 20, 9), end_date: Time.zone.local(2026, 9, 21, 17)).decorate
      expect(event.short_date_range).to eq("Sep 20-21, 2026")
    end

    it "collapses only the year for a same-year, cross-month range" do
      event = build(:event, start_date: Time.zone.local(2026, 6, 30, 9), end_date: Time.zone.local(2026, 7, 2, 17)).decorate
      expect(event.short_date_range).to eq("Jun 30 - Jul 2, 2026")
    end

    it "shows both years for a cross-year range" do
      event = build(:event, start_date: Time.zone.local(2025, 12, 31, 9), end_date: Time.zone.local(2026, 1, 2, 17)).decorate
      expect(event.short_date_range).to eq("Dec 31, 2025 - Jan 2, 2026")
    end
  end

  describe "#labelled_cost" do
    it "returns nil when cost_cents is nil" do
      event = build(:event, cost_cents: nil).decorate
      expect(event.labelled_cost).to be_nil
    end

    it "returns 'Free event' when cost_cents is 0" do
      event = build(:event, cost_cents: 0).decorate
      expect(event.labelled_cost).to eq("Free event")
    end

    it "returns whole dollars without decimals" do
      event = build(:event, cost_cents: 2500).decorate
      expect(event.labelled_cost).to eq("Cost: $25")
    end

    it "returns dollars with two decimal places when there are cents" do
      event = build(:event, cost_cents: 2550).decorate
      expect(event.labelled_cost).to eq("Cost: $25.50")
    end

    it "zero-pads single-digit cents" do
      event = build(:event, cost_cents: 2505).decorate
      expect(event.labelled_cost).to eq("Cost: $25.05")
    end

    it "adds a thousands separator for large amounts" do
      event = build(:event, cost_cents: 150_000).decorate
      expect(event.labelled_cost).to eq("Cost: $1,500")
    end
  end

  describe "#calendar_links" do
    it "falls back to rhino_description plain text when short_description is blank" do
      event = create(:event)
      event.update!(rhino_description: "<div>Join us for healing through art</div>")
      decorated = event.decorate

      html = decorated.calendar_links
      doc = Nokogiri::HTML.fragment(html)
      links = doc.css("a")

      desc_encoded = ERB::Util.url_encode("Join us for healing through art")

      google = links.find { |a| a.text == "Google" }
      expect(google["href"]).to include("details=#{desc_encoded}")

      apple = links.find { |a| a.text == "Apple" }
      expect(apple["href"]).to include("DESCRIPTION:Join us for healing through art")

      outlook = links.find { |a| a.text == "Outlook" }
      expect(outlook["href"]).to include("body=#{desc_encoded}")

      office365 = links.find { |a| a.text == "Office 365" }
      expect(office365["href"]).to include("body=#{desc_encoded}")

      yahoo = links.find { |a| a.text == "Yahoo" }
      expect(yahoo["href"]).to include("desc=#{desc_encoded}")
    end

    it "uses short_description over rhino_description when present" do
      event = create(:event, short_description: "Bring a friend!")
      event.update!(rhino_description: "<div>Join us for healing through art</div>")
      decorated = event.decorate

      doc = Nokogiri::HTML.fragment(decorated.calendar_links)
      links = doc.css("a")

      desc_encoded = ERB::Util.url_encode("Bring a friend!")

      google = links.find { |a| a.text == "Google" }
      expect(google["href"]).to include("details=#{desc_encoded}")
      expect(google["href"]).not_to include(ERB::Util.url_encode("healing through art"))

      apple = links.find { |a| a.text == "Apple" }
      expect(apple["href"]).to include("DESCRIPTION:Bring a friend!")
    end

    it "embeds the join link, meeting ID, and passcode once the details are visible" do
      event = create(:event,
                      start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours,
                      videoconference_url: "https://awbw.zoom.us/j/88285411273",
                      videoconference_passcode: "secret123")
      create(:registration_ticket_callout, event: event,
                                            builtin_key: "videoconference",
                                            display_from: 1.day.ago)

      doc = Nokogiri::HTML.fragment(event.reload.decorate.calendar_links)
      apple = doc.css("a").find { |a| a.text == "Apple" }

      expect(apple["href"]).to include("Join on Zoom: https://awbw.zoom.us/j/88285411273")
      expect(apple["href"]).to include("Meeting ID: 882 8541 1273")
      expect(apple["href"]).to include("Passcode: secret123")
    end

    it "omits the join link from every calendar link when details are gated for the registrant (payment gate)" do
      # Within the date window (details would otherwise be visible), but the
      # caller passes false — the per-registration payment gate hasn't opened.
      event = create(:event,
                      start_date: 3.days.from_now, end_date: 3.days.from_now + 2.hours,
                      videoconference_url: "https://awbw.zoom.us/j/88285411273",
                      videoconference_passcode: "secret123")
      decorated = event.decorate

      doc = Nokogiri::HTML.fragment(decorated.calendar_links(show_videoconference_details: false))
      hrefs = doc.css("a").map { |a| a["href"] }

      hrefs.each do |href|
        expect(href).not_to include("88285411273")
        expect(href).not_to include("secret123")
        expect(href).not_to include("awbw.zoom.us")
      end
    end

    it "does not leak a join link in any calendar link when the event has no videoconference URL" do
      event = create(:event,
                      start_date: 3.days.from_now, end_date: 3.days.from_now + 2.hours,
                      videoconference_url: nil)
      decorated = event.decorate

      doc = Nokogiri::HTML.fragment(decorated.calendar_links)
      hrefs = doc.css("a").map { |a| a["href"] }

      # Every provider link still renders; none carry a join URL or meeting details.
      expect(hrefs.size).to eq(5)
      hrefs.each do |href|
        expect(href).not_to include("Join on")
        expect(href).not_to include("Meeting ID")
        expect(href).not_to include("zoom.us")
      end
    end

    describe "the pending re-add note (join link present but gated)" do
      it "embeds a dated note telling the viewer to re-add the event once the link unlocks" do
        event = create(:event,
                        start_date: 30.days.from_now, end_date: 30.days.from_now + 2.hours,
                        videoconference_url: "https://awbw.zoom.us/j/88285411273")
        create(:registration_ticket_callout, event: event, builtin_key: "videoconference",
                                              display_from: 23.days.from_now)
        event.reload
        reveal = event.videoconference_details_available_from.to_date.strftime("%B %-d, %Y")

        apple = Nokogiri::HTML.fragment(event.decorate.calendar_links).css("a").find { |a| a.text == "Apple" }

        expect(apple["href"]).to include("The videoconference join link isn't in this calendar entry yet")
        expect(apple["href"]).to include("Re-download the event from the Portal on #{reveal} to include it")
        expect(apple["href"]).not_to include("88285411273")
      end

      it "uses a generic re-add note when there's no unlock date to name (payment gate)" do
        event = create(:event,
                        start_date: 3.days.from_now, end_date: 3.days.from_now + 2.hours,
                        videoconference_url: "https://awbw.zoom.us/j/88285411273")

        apple = Nokogiri::HTML.fragment(event.decorate.calendar_links(show_videoconference_details: false))
                  .css("a").find { |a| a.text == "Apple" }

        expect(apple["href"]).to include("Re-download the event from the Portal once the link is available to include it")
      end

      it "drops the note once the details are visible — the real join link takes its place" do
        event = create(:event,
                        start_date: 30.days.from_now, end_date: 30.days.from_now + 2.hours,
                        videoconference_url: "https://awbw.zoom.us/j/88285411273")
        create(:registration_ticket_callout, event: event, builtin_key: "videoconference",
                                              display_from: 1.day.ago)

        apple = Nokogiri::HTML.fragment(event.reload.decorate.calendar_links).css("a").find { |a| a.text == "Apple" }

        expect(apple["href"]).to include("Join on Zoom: https://awbw.zoom.us/j/88285411273")
        expect(apple["href"]).not_to include("Re-download the event from the Portal")
      end

      it "adds no note when the event has no videoconference URL, even while gated" do
        event = create(:event,
                        start_date: 30.days.from_now, end_date: 30.days.from_now + 2.hours,
                        videoconference_url: nil)
        create(:registration_ticket_callout, event: event, builtin_key: "videoconference",
                                              display_from: 23.days.from_now)

        hrefs = Nokogiri::HTML.fragment(event.reload.decorate.calendar_links).css("a").map { |a| a["href"] }
        hrefs.each { |href| expect(href).not_to include("Re-download the event from the Portal") }
      end

      it "links the re-download phrase to the given Portal URL in the HTML note" do
        event = create(:event,
                        start_date: 30.days.from_now, end_date: 30.days.from_now + 2.hours,
                        videoconference_url: "https://awbw.zoom.us/j/88285411273")
        create(:registration_ticket_callout, event: event, builtin_key: "videoconference",
                                              display_from: 23.days.from_now)
        event.reload
        reveal = event.videoconference_details_available_from.to_date.strftime("%B %-d, %Y")

        doc = Nokogiri::HTML.fragment(event.decorate.videoconference_calendar_pending_note_html("/registration/abc/ticket"))
        link = doc.at_css("a")

        expect(link.text).to eq("Re-download the event from the Portal")
        expect(link["href"]).to eq("/registration/abc/ticket")
        expect(doc.text).to include("on #{reveal} to include it")
      end
    end

    # The reveal date is the admin-editable drip date (display_from) on the
    # built-in videoconference callout. These drive that gate directly.
    context "with a materialized videoconference callout (admin drip date gate)" do
      def zoom_details_visible_in_all_links?(decorated)
        hrefs = Nokogiri::HTML.fragment(decorated.calendar_links).css("a").map { |a| a["href"] }
        hrefs.all? { |href| href.include?("88285411273") }
      end

      it "embeds the join link in every calendar link once the drip date has passed, even months out" do
        event = create(:event,
                        start_date: 90.days.from_now, end_date: 90.days.from_now + 2.hours,
                        videoconference_url: "https://awbw.zoom.us/j/88285411273",
                        videoconference_passcode: "secret123")
        create(:registration_ticket_callout, event: event,
                                              builtin_key: "videoconference",
                                              display_from: 1.day.ago)

        expect(zoom_details_visible_in_all_links?(event.reload.decorate)).to be(true)
      end

      it "omits the join link from every calendar link while the drip date is still in the future, even days out" do
        # Close to the start (3 days out) but the drip date hasn't arrived, so
        # the details must stay withheld regardless of proximity.
        event = create(:event,
                        start_date: 3.days.from_now, end_date: 3.days.from_now + 2.hours,
                        videoconference_url: "https://awbw.zoom.us/j/88285411273",
                        videoconference_passcode: "secret123")
        create(:registration_ticket_callout, event: event,
                                              builtin_key: "videoconference",
                                              display_from: 1.day.from_now)

        hrefs = Nokogiri::HTML.fragment(event.reload.decorate.calendar_links).css("a").map { |a| a["href"] }
        # Guard against a change that only wires the gate into some providers:
        # the join link and passcode must be absent from all of them.
        hrefs.each do |href|
          expect(href).not_to include("88285411273")
          expect(href).not_to include("secret123")
          expect(href).not_to include("awbw.zoom.us")
        end
      end

      it "embeds the join link immediately when the drip date is blank (no gate), even months out" do
        event = create(:event,
                        start_date: 90.days.from_now, end_date: 90.days.from_now + 2.hours,
                        videoconference_url: "https://awbw.zoom.us/j/88285411273",
                        videoconference_passcode: "secret123")
        create(:registration_ticket_callout, event: event,
                                              builtin_key: "videoconference",
                                              display_from: nil)

        expect(zoom_details_visible_in_all_links?(event.reload.decorate)).to be(true)
      end
    end
  end

  describe "#times" do
    it "shows a multi-day event as a date range with a single daily time range" do
      event = build(:event, start_date: Time.zone.local(2026, 4, 21, 9), end_date: Time.zone.local(2026, 4, 23, 16, 30)).decorate
      tz = Time.zone.local(2026, 4, 21, 9).strftime("%Z")
      expect(event.times(display_day: true, display_date: true)).to eq("Tue-Thu, Apr 21-23 @ 9 am - 4:30 pm #{tz}")
    end

    it "shows a cross-month multi-day event with both months" do
      event = build(:event, start_date: Time.zone.local(2026, 4, 30, 9), end_date: Time.zone.local(2026, 5, 2, 16, 30)).decorate
      tz = Time.zone.local(2026, 4, 30, 9).strftime("%Z")
      expect(event.times(display_day: true, display_date: true)).to eq("Thu-Sat, Apr 30 - May 2 @ 9 am - 4:30 pm #{tz}")
    end
  end
end
