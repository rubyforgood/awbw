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

    # notification.sender is an internal audit field only. Recipients must keep
    # seeing the generic mailbox with no personal name attached, both because
    # SendGrid only authorizes our own domain and because we're not ready to
    # change what the public sees.
    context "sender attribution stays out of the delivered email" do
      let(:event_registration) { create(:event_registration) }
      let(:admin) { create(:user, first_name: "Dana", last_name: "Sender") }
      let(:notification) do
        create(:notification,
          kind: "event_registration_reminder",
          noticeable: event_registration,
          recipient_role: "person",
          recipient_email: event_registration.registrant.preferred_email,
          sender: admin)
      end

      it "sends an attributed reminder from the generic address with no display name" do
        described_class.new.perform(notification.id)

        mail = ActionMailer::Base.deliveries.last
        expect(mail.from).to eq([ ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org") ])
        expect(mail[:from].display_names.compact).to be_empty
        expect(mail.reply_to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
      end

      it "never names the sender in any header" do
        described_class.new.perform(notification.id)

        headers = ActionMailer::Base.deliveries.last.header.fields.map(&:to_s).join("\n")
        expect(headers).not_to include("Dana Sender")
      end

      it "still records the sender for the communications pages" do
        described_class.new.perform(notification.id)

        expect(notification.reload.sender).to eq(admin)
        expect(notification.decorate.sender_name).to eq("Dana Sender")
      end
    end
  end
end
