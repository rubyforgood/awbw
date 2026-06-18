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

    it "embeds the join link, meeting ID, and passcode within a week of the event" do
      event = create(:event,
                      start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours,
                      videoconference_url: "https://awbw.zoom.us/j/88285411273",
                      videoconference_passcode: "secret123")
      decorated = event.decorate

      doc = Nokogiri::HTML.fragment(decorated.calendar_links)
      apple = doc.css("a").find { |a| a.text == "Apple" }

      expect(apple["href"]).to include("Join on Zoom: https://awbw.zoom.us/j/88285411273")
      expect(apple["href"]).to include("Meeting ID: 882 8541 1273")
      expect(apple["href"]).to include("Passcode: secret123")
    end

    it "omits the join link, meeting ID, and passcode more than a week out" do
      event = create(:event,
                      start_date: 8.days.from_now, end_date: 8.days.from_now + 2.hours,
                      videoconference_url: "https://awbw.zoom.us/j/88285411273",
                      videoconference_passcode: "secret123")
      decorated = event.decorate

      doc = Nokogiri::HTML.fragment(decorated.calendar_links)
      apple = doc.css("a").find { |a| a.text == "Apple" }

      expect(apple["href"]).not_to include("88285411273")
      expect(apple["href"]).not_to include("Meeting ID")
      expect(apple["href"]).not_to include("secret123")
    end

    it "emits all-day calendar entries when the event has no time" do
      event = build(:event,
                    start_date: Time.zone.local(2026, 7, 23).beginning_of_day,
                    end_date: Time.zone.local(2026, 7, 23).beginning_of_day).decorate
      doc = Nokogiri::HTML.fragment(event.calendar_links)
      hrefs = doc.css("a").to_h { |a| [ a.text, a["href"] ] }

      # End date is exclusive, so a single all-day day spans 07-23 to 07-24.
      expect(hrefs["Google"]).to include("dates=20260723/20260724")
      expect(hrefs["Apple"]).to include("DTSTART;VALUE=DATE:20260723")
      expect(hrefs["Apple"]).to include("DTEND;VALUE=DATE:20260724")
      expect(hrefs["Outlook"]).to include("startdt=2026-07-23&enddt=2026-07-24&allday=true")
      expect(hrefs["Yahoo"]).to include("st=20260723&dur=allday")
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

  describe "#times for all-day events" do
    it "renders only the date when no time is set" do
      event = build(:event,
                    start_date: Time.zone.local(2026, 7, 23).beginning_of_day,
                    end_date: Time.zone.local(2026, 7, 23).beginning_of_day).decorate
      expect(event.times(display_day: true, display_date: true)).to eq("Thu, Jul 23")
    end

    it "renders only the date range for a multi-day all-day event" do
      event = build(:event,
                    start_date: Time.zone.local(2026, 7, 23).beginning_of_day,
                    end_date: Time.zone.local(2026, 7, 24).beginning_of_day).decorate
      expect(event.times(display_day: true, display_date: true)).to eq("Thu, Jul 23 - Fri, Jul 24")
    end

    it "omits the time line in the styled layout" do
      event = build(:event,
                    start_date: Time.zone.local(2026, 7, 23).beginning_of_day,
                    end_date: Time.zone.local(2026, 7, 23).beginning_of_day).decorate
      expect(event.times(styled: true)).to eq("Thursday, July 23")
    end
  end
end
