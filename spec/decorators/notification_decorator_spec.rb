require "rails_helper"

RSpec.describe NotificationDecorator, type: :decorator do
  describe "#sender_name" do
    it "names the staff member who sent it" do
      sender = build_stubbed(:user, first_name: "Dana", last_name: "Sender", person: nil)

      expect(build_stubbed(:notification, sender: sender).decorate.sender_name).to eq("Dana Sender")
    end

    it "falls back to the portal when nobody sent it by hand" do
      expect(build_stubbed(:notification, sender: nil).decorate.sender_name).to eq("AWBW Portal")
    end
  end

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
