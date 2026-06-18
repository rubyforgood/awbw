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
          custom_message: "Bring <strong>your supplies</strong>.")
      end

      it "delivers the reminder and persists the body with the custom message" do
        expect {
          described_class.new.perform(notification.id)
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        notification.reload
        expect(notification.delivered_at).to be_present
        expect(notification.email_body_html).to include("Bring <strong>your supplies</strong>.")
      end
    end
  end
end
