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

  describe "#title" do
    it "references the subject record when one is linked" do
      notification = build_stubbed(:notification, noticeable_type: "Person", noticeable_id: 42)

      expect(notification.decorate.title).to eq("Re Person #42")
    end

    it "falls back to the recipient when the subject record was deleted (nullified)" do
      notification = build_stubbed(:notification, noticeable: nil, recipient_email: "kim@example.com")

      expect(notification.decorate.title).to eq("Re kim@example.com")
    end
  end

  describe "#row_class" do
    it "tints the row amber for an email stuck pending past the grace period" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: nil, created_at: 2.hours.ago)

      expect(notification.decorate.row_class).to eq("bg-amber-50 hover:bg-amber-100")
    end

    it "tints the row red for a failed email" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: Time.current)

      expect(notification.decorate.row_class).to eq("bg-red-50 hover:bg-red-100")
    end

    it "uses the default hover treatment for a fresh in-flight send" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: nil, created_at: 5.minutes.ago)

      expect(notification.decorate.row_class).to eq("hover:bg-gray-50")
    end

    it "uses the default hover treatment once delivered" do
      notification = build_stubbed(:notification, delivered_at: Time.current)

      expect(notification.decorate.row_class).to eq("hover:bg-gray-50")
    end

    it "uses the default hover treatment for an archived (pre-launch) email" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: nil, created_at: Date.new(2025, 12, 1))

      expect(notification.decorate.row_class).to eq("hover:bg-gray-50")
    end
  end

  describe "#card_bg_class" do
    it "uses the amber warning background for an email stuck pending past the grace period" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: nil, created_at: 2.hours.ago)

      expect(notification.decorate.card_bg_class).to eq("bg-amber-50 border-amber-300")
    end

    it "uses the red error background for a failed email" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: Time.current)

      expect(notification.decorate.card_bg_class).to eq("bg-red-50 border-red-300")
    end

    it "uses the notifications domain colour for a fresh in-flight send" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: nil, created_at: 5.minutes.ago)

      expect(notification.decorate.card_bg_class).to eq("#{DomainTheme.bg_class_for(:notifications)} border-gray-200")
    end

    it "uses the notifications domain colour once delivered" do
      notification = build_stubbed(:notification, delivered_at: Time.current)

      expect(notification.decorate.card_bg_class).to eq("#{DomainTheme.bg_class_for(:notifications)} border-gray-200")
    end

    it "uses the notifications domain colour for an archived (pre-launch) email" do
      notification = build_stubbed(:notification, delivered_at: nil, error_at: nil, created_at: Date.new(2025, 12, 1))

      expect(notification.decorate.card_bg_class).to eq("#{DomainTheme.bg_class_for(:notifications)} border-gray-200")
    end
  end

  describe "#from_name / #to_name" do
    let(:sender) { build_stubbed(:user, first_name: "Dana", last_name: "Sender", person: nil) }

    it "puts the sender on From and the recipient on To for an outgoing communication" do
      notification = build_stubbed(:notification, sender: sender, recipient_email: "kim@example.com").decorate
      expect(notification.from_name).to eq("Dana Sender")
      expect(notification.to_name).to eq("kim@example.com")
    end

    it "flips them for an incoming communication — the person is From, the author is To" do
      notification = build_stubbed(:notification, :incoming, sender: sender, recipient_email: "kim@example.com").decorate
      expect(notification.from_name).to eq("kim@example.com")
      expect(notification.to_name).to eq("Dana Sender")
    end
  end

  describe "person-name resolution" do
    it "shows the person's name and hovers the email when the recipient is on file" do
      create(:person, first_name: "Tiombe", last_name: "Wallace", email: "tiombe@example.com")
      decorated = create(:notification, recipient_email: "tiombe@example.com").decorate

      expect(decorated.to_name).to eq("Tiombe Wallace")
      expect(decorated.to_title).to eq("tiombe@example.com")
    end

    it "falls back to the raw email (no hover) when nobody matches" do
      decorated = build_stubbed(:notification, recipient_email: "stranger@example.com").decorate

      expect(decorated.to_name).to eq("stranger@example.com")
      expect(decorated.to_title).to be_nil
    end
  end

  describe "#to_person / #from_person" do
    it "puts the contact on the To side of an outgoing communication" do
      person = create(:person, email: "kim@example.com")
      decorated = create(:notification, recipient_email: "kim@example.com").decorate

      expect(decorated.to_person).to eq(person)
      expect(decorated.from_person).to be_nil
    end

    it "puts the contact on the From side of an incoming communication" do
      person = create(:person, email: "kim@example.com")
      decorated = create(:notification, :incoming, recipient_email: "kim@example.com").decorate

      expect(decorated.from_person).to eq(person)
      expect(decorated.to_person).to be_nil
    end

    it "has no person when the contact isn't on file" do
      decorated = build_stubbed(:notification, recipient_email: "stranger@example.com").decorate

      expect(decorated.to_person).to be_nil
      expect(decorated.from_person).to be_nil
    end
  end

  describe "#to_value / #from_value" do
    it "links the resolved contact to their profile" do
      person = create(:person, email: "kim@example.com")
      decorated = create(:notification, recipient_email: "kim@example.com").decorate

      expect(decorated.to_value).to include("href=\"#{Rails.application.routes.url_helpers.person_path(person)}\"")
    end

    it "links an unresolved contact email as a mailto" do
      decorated = build_stubbed(:notification, recipient_email: "stranger@example.com").decorate

      expect(decorated.to_value).to include("href=\"mailto:stranger@example.com\"")
    end

    it "leaves the AWBW Portal side as plain text, not a link" do
      decorated = build_stubbed(:notification, sender: nil, recipient_email: "kim@example.com").decorate

      expect(decorated.from_value).to include("AWBW Portal")
      expect(decorated.from_value).not_to include("<a")
    end
  end

  describe "#audience" do
    it "is incoming for a communication the person sent" do
      expect(build_stubbed(:notification, :incoming).decorate.audience).to eq("incoming")
    end

    it "is fyi for an admin-directed communication" do
      expect(build_stubbed(:notification, recipient_role: "admin").decorate.audience).to eq("fyi")
    end

    it "is nil for a normal message to the person" do
      expect(build_stubbed(:notification, recipient_role: "person").decorate.audience).to be_nil
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

  describe "#flag_badges" do
    it "shows a sky Incoming pill for an incoming communication" do
      html = build_stubbed(:notification, :incoming).decorate.flag_badges
      expect(html).to include("bg-sky-100")
      expect(html).to include("Incoming")
    end

    it "shows a teal FYI pill for an admin-directed communication" do
      html = build_stubbed(:notification, recipient_role: "admin").decorate.flag_badges
      expect(html).to include("bg-teal-100")
      expect(html).to include("FYI")
    end

    it "shows a Bulk pill for a bulk communication, alongside FYI when it's an FYI copy" do
      html = build_stubbed(:notification, kind: "bulk_payment_confirmation_fyi", recipient_role: "admin").decorate.flag_badges
      expect(html).to include("Bulk")
      expect(html).to include("FYI")
    end

    it "shows only Bulk for the bulk copy sent to the person" do
      html = build_stubbed(:notification, kind: "bulk_payment_confirmation", recipient_role: "person").decorate.flag_badges
      expect(html).to include("Bulk")
      expect(html).not_to include("FYI")
      expect(html).not_to include("Incoming")
    end

    it "shows a Bulk pill for a send flagged via the bulk column, even when its kind isn't bulk_" do
      html = build_stubbed(:notification, :bulk, kind: "event_registration_reminder", recipient_role: "person").decorate.flag_badges
      expect(html).to include("Bulk")
      expect(html).not_to include("FYI")
      expect(html).not_to include("Incoming")
    end

    it "renders nothing for a plain message to the person" do
      expect(build_stubbed(:notification, recipient_role: "person").decorate.flag_badges).to eq("")
    end

    it "appends a caller-supplied class to each pill" do
      html = build_stubbed(:notification, :incoming).decorate.flag_badges(class: "mr-1")
      expect(html).to include("mr-1")
      expect(html).to include("bg-sky-100")
    end
  end
end
