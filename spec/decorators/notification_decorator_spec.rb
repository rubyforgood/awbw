require "rails_helper"

RSpec.describe NotificationDecorator, type: :decorator do
  describe "#channel_icon" do
    {
      "email" => "fa-envelope",
      "autoemail" => "fa-envelope",
      "phone" => "fa-phone",
      "text" => "fa-mobile-screen-button",
      "video" => "fa-video"
    }.each do |channel, icon_class|
      it "renders the solid #{icon_class} icon for the #{channel} channel" do
        html = build_stubbed(:notification, channel: channel).decorate.channel_icon
        expect(html).to include("fa-solid")
        expect(html).to include(icon_class)
      end
    end

    it "renders nothing for a blank or unknown channel" do
      expect(build_stubbed(:notification, channel: nil).decorate.channel_icon).to eq("")
    end
  end
end
