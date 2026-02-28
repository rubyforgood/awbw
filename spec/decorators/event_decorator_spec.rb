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

    it "returns 'video call' for invalid URLs" do
      event = build(:event, videoconference_url: "not a url").decorate
      expect(event.videoconference_domain).to eq("video call")
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
  end

  describe "#calendar_links" do
    it "includes rhino_description plain text in all calendar links" do
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
  end
end
