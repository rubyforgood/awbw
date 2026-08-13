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

  describe "#row_class" do
    it "tints the row amber for a pending (not-yet-delivered) email" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: nil)

      expect(notification.decorate.row_class).to eq("bg-amber-50 hover:bg-amber-100")
    end

    it "tints the row red for a failed email" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: Time.current)

      expect(notification.decorate.row_class).to eq("bg-red-50 hover:bg-red-100")
    end

    it "uses the default hover treatment once delivered" do
      notification = build_stubbed(:notification, delivered_at: Time.current)

      expect(notification.decorate.row_class).to eq("hover:bg-gray-50")
    end
  end

  describe "#card_bg_class" do
    it "uses the amber warning background for a pending email" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: nil)

      expect(notification.decorate.card_bg_class).to eq("bg-amber-50 border-amber-300")
    end

    it "uses the red error background for a failed email" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: Time.current)

      expect(notification.decorate.card_bg_class).to eq("bg-red-50 border-red-300")
    end

    it "uses the notifications domain colour once delivered" do
      notification = build_stubbed(:notification, delivered_at: Time.current)

      expect(notification.decorate.card_bg_class).to eq("#{DomainTheme.bg_class_for(:notifications)} border-gray-200")
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
