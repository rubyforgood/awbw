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
end
