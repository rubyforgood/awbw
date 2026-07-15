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

    context "when a scholarship was not requested" do
      let(:event_registration) { create(:event_registration, scholarship_requested: false) }

      it "labels the subject as a plain event registration" do
        expect(mail.subject).to include("Event registration received")
        expect(mail.subject).not_to include("scholarship")
      end
    end

    context "when a scholarship was requested" do
      let(:event_registration) { create(:event_registration, scholarship_requested: true) }

      it "labels the subject as an event scholarship registration" do
        expect(mail.subject).to include("Event scholarship registration received")
      end
    end

    it "includes the event title in the body" do
      expect(mail.body.encoded).to include(event_registration.event.title)
    end

    it "includes the registrant name in the body" do
      expect(mail.body.encoded).to include(event_registration.registrant.full_name)
    end

    it "links to the registrant's ticket" do
      expect(mail.body.encoded).to include("/registration/#{event_registration.slug}")
    end

    it "offers only the ticket call to action, not a separate event link" do
      body = mail.body.encoded

      expect(body).to include("View ticket")
      expect(body).not_to include("View event")
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

    context "for a virtual event" do
      let(:event) { create(:event, videoconference_url: "https://zoom.us/j/123", videoconference_label: "Zoom", videoconference_passcode: "secret123") }
      let(:event_registration) { create(:event_registration, event: event) }

      it "shows the platform label as plain text" do
        expect(mail.html_part.body.encoded).to include("Zoom")
        expect(mail.text_part.body.encoded).to include("Zoom")
      end

      it "does not include the join link, meeting ID, or passcode" do
        body = mail.body.encoded
        expect(body).not_to include("https://zoom.us/j/123")
        expect(body).not_to include("secret123")
        expect(body).not_to include("Meeting ID")
      end
    end

    context "when the event is CE-eligible and has deadlines" do
      let(:event) do
        create(:event, ce_hours_offered: 6,
                       ce_hours_request_deadline: Date.new(2026, 7, 1),
                       ce_payment_due_deadline: Date.new(2026, 8, 15))
      end
      let(:event_registration) { create(:event_registration, event: event) }

      it "surfaces both CE deadlines in the body" do
        expect(mail.body.encoded).to include("Request CE credit by")
        expect(mail.body.encoded).to include("July 1, 2026")
        expect(mail.body.encoded).to include("CE payment due by")
        expect(mail.body.encoded).to include("August 15, 2026")
      end
    end

    context "when the event is not CE-eligible" do
      let(:event) { create(:event, ce_hours_offered: nil, ce_hours_request_deadline: Date.new(2026, 7, 1)) }
      let(:event_registration) { create(:event_registration, event: event) }

      it "omits the CE deadlines" do
        expect(mail.body.encoded).not_to include("Request CE credit by")
      end
    end
  end

  describe "#bulk_payment_confirmation" do
    let(:event) { create(:event) }
    let(:form) do
      f = FormBuilderService.new(name: "Bulk Payment", sections: %i[bulk_payment], role: "bulk_payment").call
      event.event_forms.create!(form: f, role: "bulk_payment")
      f
    end
    let(:person) { create(:person, first_name: "Pat", last_name: "Payer", email: "pat@example.com") }
    let(:submission) do
      s = FormSubmission.create!(form: form, person: person, event: event, role: "bulk_payment")
      s.form_answers.create!(form_field: form.form_fields.find_by(field_identifier: "number_of_attendees"), submitted_answer: "4")
      s.form_answers.create!(form_field: form.form_fields.find_by(field_identifier: "payment_method"), submitted_answer: "Check")
      s
    end
    let(:mail) { described_class.bulk_payment_confirmation(submission) }

    it "renders without raising" do
      expect { mail.deliver_now }.not_to raise_error
    end

    it "sends to the payer" do
      expect(mail.to).to eq([ person.preferred_email ])
    end

    it "includes the event title in the subject" do
      expect(mail.subject).to include(event.title)
    end

    it "includes the number of attendees and payment method in the body" do
      body = mail.body.encoded
      expect(body).to include("4")
      expect(body).to include("Check")
    end

    it "includes the submitted payment total in the body" do
      # Event cost (1099¢) × 4 attendees = $43.96
      expect(mail.body.encoded).to include("$43.96")
    end
  end

  describe "#event_registration_reminder" do
    let(:event_registration) { create(:event_registration) }
    let(:mail) { described_class.event_registration_reminder(event_registration) }

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

    context "when the event is CE-eligible and has deadlines" do
      let(:event) do
        create(:event, ce_hours_offered: 6,
                       ce_hours_request_deadline: Date.new(2026, 7, 1),
                       ce_payment_due_deadline: Date.new(2026, 8, 15))
      end
      let(:event_registration) { create(:event_registration, event: event) }

      it "surfaces both CE deadlines in the body" do
        expect(mail.body.encoded).to include("Request CE credit by")
        expect(mail.body.encoded).to include("July 1, 2026")
        expect(mail.body.encoded).to include("CE payment due by")
        expect(mail.body.encoded).to include("August 15, 2026")
      end
    end

    context "with a custom subject" do
      let(:mail) { described_class.event_registration_reminder(event_registration, custom_subject: "Don't forget us tomorrow!") }

      it "uses the custom subject verbatim" do
        expect(mail.subject).to eq("Don't forget us tomorrow!")
      end
    end

    context "with a blank custom subject" do
      let(:mail) { described_class.event_registration_reminder(event_registration, custom_subject: " ") }

      it "falls back to the default portal subject" do
        expect(mail.subject).to include("Reminder: #{event_registration.event.title}")
      end
    end

    context "for a virtual event" do
      let(:event) { create(:event, videoconference_url: "https://zoom.us/j/123", videoconference_label: "Zoom") }
      let(:event_registration) { create(:event_registration, event: event) }

      it "shows the event's platform label as plain text" do
        expect(mail.html_part.body.encoded).to include("Zoom")
      end

      it "does not link to the videoconference URL" do
        expect(mail.html_part.body.encoded).not_to include("https://zoom.us/j/123")
      end
    end

    context "for a multi-day event" do
      let(:event) do
        create(:event,
          start_date: Time.zone.local(2026, 8, 16, 19, 0),
          end_date: Time.zone.local(2026, 8, 17, 21, 0))
      end
      let(:event_registration) { create(:event_registration, event: event) }

      it "shows the dates as a single hyphenated range, not one line per day" do
        expect(mail.html_part.body.encoded).to include("August 16-17")
      end
    end

    context "with a custom message" do
      let(:mail) { described_class.event_registration_reminder(event_registration, custom_message: custom_message) }
      let(:custom_message) { "Please bring <strong>your art supplies</strong>." }

      it "includes the message in the HTML body" do
        expect(mail.html_part.body.encoded).to include("Please bring <strong>your art supplies</strong>.")
      end

      it "includes the message text in the plain-text body" do
        expect(mail.text_part.body.encoded).to include("Please bring your art supplies.")
      end

      it "strips disallowed HTML from the message" do
        mail = described_class.event_registration_reminder(event_registration, custom_message: "Hi<script>alert(1)</script>")
        expect(mail.html_part.body.encoded).to include("Hi")
        expect(mail.html_part.body.encoded).not_to include("<script>")
      end
    end

    context "without a custom message" do
      it "does not render the custom-message container" do
        expect(mail.html_part.body.encoded).not_to include("reminder-custom-message")
      end
    end

    context "in preview mode" do
      let(:mail) { described_class.event_registration_reminder(event_registration, preview: true) }

      it "renders the custom-message container even when blank" do
        expect(mail.html_part.body.encoded).to include("reminder-custom-message")
      end
    end
  end

  describe "#event_registration_reminder_fyi" do
    let(:event) { create(:event, title: "Art Workshop") }
    let(:recipient_labels) { [ "Alex Rivera <alex@example.org>", "Sam Lee <sam@example.org>" ] }
    let(:mail) { described_class.event_registration_reminder_fyi(event, recipient_labels, custom_message: "See you soon!") }

    it "renders without raising" do
      expect { mail.deliver_now }.not_to raise_error
    end

    it "is sent to the admin reply-to address" do
      expect(mail.to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
    end

    it "summarizes the count and event in the subject" do
      expect(mail.subject).to include("[FYI]")
      expect(mail.subject).to include("2 registrants")
      expect(mail.subject).to include("Art Workshop")
    end

    it "lists every recipient in the body" do
      expect(mail.html_part.body.encoded).to include("Alex Rivera").and include("Sam Lee")
      expect(mail.text_part.body.encoded).to include("Alex Rivera <alex@example.org>")
    end

    it "includes the custom message and event title" do
      expect(mail.html_part.body.encoded).to include("See you soon!")
      expect(mail.html_part.body.encoded).to include("Art Workshop")
    end

    it "uses the singular noun for a single recipient" do
      mail = described_class.event_registration_reminder_fyi(event, [ "Alex Rivera <alex@example.org>" ])
      expect(mail.subject).to include("1 registrant ")
    end
  end
end
