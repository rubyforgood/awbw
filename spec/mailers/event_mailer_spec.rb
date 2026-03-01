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

  describe "#event_registration_cancelled" do
    let(:event_registration) { create(:event_registration) }
    let(:mail) { described_class.event_registration_cancelled(event_registration) }

    it "renders without raising" do
      expect { mail.deliver_now }.not_to raise_error
    end

    it "sends to the registrant" do
      expect(mail.to).to eq([ event_registration.registrant.preferred_email ])
    end

    it "includes the event title in the subject" do
      expect(mail.subject).to include(event_registration.event.title)
    end
  end
end
