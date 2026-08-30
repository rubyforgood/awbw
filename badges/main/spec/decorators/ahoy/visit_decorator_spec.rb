require "rails_helper"

RSpec.describe Ahoy::VisitDecorator do
  def decorate(user_agent)
    build(:ahoy_visit, user_agent: user_agent).decorate
  end

  describe "#user_agent_summary" do
    it "renders device, then OS, then browser" do
      ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:5.0) Gecko/20100101 Firefox/5.0"
      expect(decorate(ua).user_agent_summary).to eq("Desktop · Windows 10 · Firefox 5.0")
    end

    it "labels smartphones as Mobile" do
      ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " \
           "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
      expect(decorate(ua).user_agent_summary).to eq("Mobile · iOS 17.0 · Mobile Safari 17.0")
    end

    it "returns Unknown when the user agent is blank" do
      expect(decorate(nil).user_agent_summary).to eq("Unknown")
    end

    it "returns Unknown when the user agent can't be parsed" do
      expect(decorate("not-a-real-user-agent").user_agent_summary).to eq("Unknown")
    end
  end

  describe "#user_agent_details" do
    it "returns the raw user agent string for the hover title" do
      ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:5.0) Gecko/20100101 Firefox/5.0"
      expect(decorate(ua).user_agent_details).to eq(ua)
    end

    it "is blank when the user agent is blank" do
      expect(decorate(nil).user_agent_details).to eq("")
    end
  end
end
