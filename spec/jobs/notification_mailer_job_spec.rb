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

    it "delivers the account_email_change_requested_notification email" do
      user = create(:user, email: "old@example.com")
      user.update_columns(unconfirmed_email: "new@example.com")
      notif = create(:notification,
        kind: "account_email_change_requested_notification",
        noticeable: user,
        recipient_role: "person",
        recipient_email: "old@example.com")

      expect {
        described_class.new.perform(notif.id)
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      notif.reload
      expect(notif.delivered_at).to be_present
      expect(notif.email_subject).to include("email change was requested")
    end

    it "raises for unknown notification kinds" do
      notification.update_column(:kind, "reset_password") # valid kind but no mailer mapping

      expect {
        described_class.new.perform(notification.id)
      }.to raise_error(/Unknown notification kind/)
    end
  end
end
