require "rails_helper"

RSpec.describe EventMailer, type: :mailer do
  describe "#event_registration_confirmation" do
    let(:event_registration) { create(:event_registration) }
    let(:mail) { described_class.event_registration_confirmation(event_registration) }

    it "renders without raising" do
      expect { mail.deliver_now }.not_to raise_error
    end

    it "sends to the registrant" do
      expect(mail.to).to eq([ event_registration.registrant.preferred_email ])
    end

    it "includes the event title in the subject" do
      expect(mail.subject).to include(event_registration.event.title)
    end

    it "includes the event title in the body" do
      expect(mail.body.encoded).to include(event_registration.event.title)
    end

    it "includes the registrant name in the body" do
      expect(mail.body.encoded).to include(event_registration.registrant.full_name)
    end

    context "when the event has a rhino_description" do
      let(:event) { create(:event, rhino_description: "Join us for an art healing workshop") }
      let(:event_registration) { create(:event_registration, event: event) }

      it "includes the rhino_description in the body" do
        expect(mail.body.encoded).to include("Join us for an art healing workshop")
      end

      it "includes the Details heading" do
        expect(mail.body.encoded).to include("Details")
      end
    end

    context "when the event has no rhino_description" do
      let(:event_registration) { create(:event_registration) }

      it "does not include the Details section" do
        expect(mail.body.encoded).not_to include("<strong>Details</strong>")
      end
    end
  end

  describe "#event_registration_reminder" do
    let(:event_registration) { create(:event_registration) }
    let(:mail) { described_class.event_registration_reminder(event_registration, days_until_event: days_until_event) }
    let(:days_until_event) { 7 }

    it "renders without raising" do
      expect { mail.deliver_now }.not_to raise_error
    end

    it "sends to the registrant" do
      expect(mail.to).to eq([ event_registration.registrant.preferred_email ])
    end

    it "includes the event title in the subject" do
      expect(mail.subject).to include(event_registration.event.title)
    end

    it "includes the event title in the body" do
      expect(mail.body.encoded).to include(event_registration.event.title)
    end

    it "includes the registrant name in the body" do
      expect(mail.body.encoded).to include(event_registration.registrant.full_name)
    end

    it "includes reminder wording in the body" do
      expect(mail.body.encoded).to include("This is a reminder that you're registered for the following")
    end

    context "when days_until_event is 0" do
      let(:days_until_event) { 0 }

      it "includes today in the body" do
        expect(mail.body.encoded).to include("today")
      end
    end

    context "when days_until_event is 1" do
      let(:days_until_event) { 1 }

      it "includes tomorrow in the body" do
        expect(mail.body.encoded).to include("tomorrow")
      end
    end

    context "when days_until_event is 7" do
      let(:days_until_event) { 7 }

      it "includes the number of days in the body" do
        expect(mail.body.encoded).to include("7 days")
      end
    end

    context "when days_until_event is nil" do
      let(:days_until_event) { nil }
      let(:mail) { described_class.event_registration_reminder(event_registration) }

      it "renders without raising" do
        expect { mail.deliver_now }.not_to raise_error
      end

      it "does not include today, tomorrow, or in N days in the body" do
        body = mail.body.encoded
        expect(body).not_to include("today")
        expect(body).not_to include("tomorrow")
        expect(body).not_to match(/\bin \d+ days\b/)
      end
    end
  end
end
