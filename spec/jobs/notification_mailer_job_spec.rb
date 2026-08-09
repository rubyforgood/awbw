require "rails_helper"

RSpec.describe NotificationMailerJob, type: :job do
  describe "#perform" do
    let(:notification) { create(:notification, kind: "reset_password_fyi") }

    it "delivers the email and persists it" do
      expect {
        described_class.new.perform(notification.id)
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      notification.reload
      expect(notification.delivered_at).to be_present
      expect(notification.email_subject).to be_present
    end

    it "skips already-delivered notifications" do
      notification.update!(delivered_at: Time.current)

      expect {
        described_class.new.perform(notification.id)
      }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it "records error on the notification when delivery fails" do
      allow(NotificationMailer).to receive(:reset_password_fyi)
        .and_raise(Net::SMTPServerBusy, "450 Too many connections")

      expect {
        described_class.new.perform(notification.id)
      }.to raise_error(Net::SMTPServerBusy)

      notification.reload
      expect(notification.error_class).to eq("Net::SMTPServerBusy")
      expect(notification.error_message).to include("Too many connections")
      expect(notification.error_at).to be_present
      expect(notification.delivered_at).to be_nil
    end

    it "raises for unknown notification kinds" do
      notification.update_column(:kind, "reset_password") # valid kind but no mailer mapping

      expect {
        described_class.new.perform(notification.id)
      }.to raise_error(/Unknown notification kind/)
    end

    context "for an event registration reminder" do
      let(:event_registration) { create(:event_registration) }
      let(:notification) do
        create(:notification,
          kind: "event_registration_reminder",
          noticeable: event_registration,
          recipient_role: "person",
          recipient_email: event_registration.registrant.preferred_email,
          custom_message: "Bring <strong>your supplies</strong>.",
          custom_subject: "Don't forget us tomorrow!")
      end

      it "delivers the reminder and persists the body with the custom message" do
        expect {
          described_class.new.perform(notification.id)
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        notification.reload
        expect(notification.delivered_at).to be_present
        expect(notification.email_body_html).to include("Bring <strong>your supplies</strong>.")
      end

      it "delivers with the notification's custom subject" do
        described_class.new.perform(notification.id)

        expect(ActionMailer::Base.deliveries.last.subject).to eq("Don't forget us tomorrow!")
      end
    end

    # We only have SendGrid authorization for our own domain, so an attributed
    # reminder may name the admin in the display name but never in the address.
    context "sender attribution on the From header" do
      let(:event_registration) { create(:event_registration) }
      let(:admin) { create(:user, first_name: "Dana", last_name: "Sender") }

      def reminder_for(sender)
        create(:notification,
          kind: "event_registration_reminder",
          noticeable: event_registration,
          recipient_role: "person",
          recipient_email: event_registration.registrant.preferred_email,
          sender: sender)
      end

      it "names the sending admin in the display name only" do
        described_class.new.perform(reminder_for(admin).id)

        mail = ActionMailer::Base.deliveries.last
        expect(mail[:from].display_names).to eq([ "Dana Sender" ])
        expect(mail.from).to eq([ ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org") ])
      end

      it "leaves reply_to on the generic address so replies come back to us" do
        described_class.new.perform(reminder_for(admin).id)

        expect(ActionMailer::Base.deliveries.last.reply_to)
          .to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
      end

      it "sends automated mail with no display name" do
        described_class.new.perform(reminder_for(nil).id)

        mail = ActionMailer::Base.deliveries.last
        expect(mail[:from].display_names.compact).to be_empty
        expect(mail.from).to eq([ ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org") ])
      end
    end
  end
end
