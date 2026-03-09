require "rails_helper"

RSpec.describe DeviseMailer, type: :mailer do
  let(:user) { create(:user, email: "user@example.com") }
  let(:token) { "fake-token-123" }

  describe "#track_devise_email_event" do
    context "when sending confirmation for initial signup" do
      it "tracks auth.confirmation_email_sent" do
        expect(Analytics::AhoyTracker).to receive(:track_auth_event).with(
          "auth.confirmation_email_sent",
          hash_including(record_id: user.id, record_type: "User"),
          user: anything
        )

        described_class.confirmation_instructions(user, token).deliver_now
      end
    end

    context "when sending confirmation for email change (reconfirmation)" do
      before do
        user.skip_confirmation_notification!
        user.update!(email: "new@example.com")
        # Devise sets unconfirmed_email and keeps original email
      end

      it "tracks auth.email_change_requested_email_sent instead of confirmation_email_sent" do
        expect(Analytics::AhoyTracker).to receive(:track_auth_event).with(
          "auth.email_change_requested_email_sent",
          hash_including(record_id: user.id, record_type: "User"),
          user: anything
        )

        described_class.confirmation_instructions(user, token).deliver_now
      end
    end

    context "when sending reset password instructions" do
      it "tracks auth.reset_password_email_sent" do
        expect(Analytics::AhoyTracker).to receive(:track_auth_event).with(
          "auth.reset_password_email_sent",
          hash_including(record_id: user.id, record_type: "User"),
          user: anything
        )

        described_class.reset_password_instructions(user, token).deliver_now
      end
    end

    # unlock_instructions not tested here — app uses unlock_strategy: :none
    # so user_unlock_url route doesn't exist and the view can't render
  end

  describe "#create_notification_record" do
    let(:notification) { build(:notification) }

    before do
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(NotificationServices::PersistDeliveredEmail).to receive(:call)
      allow(NotificationServices::CreateNotification).to receive(:call).and_return(notification)
    end

    context "when sending confirmation for initial signup" do
      it "creates an account_confirmation notification" do
        expect(NotificationServices::CreateNotification).to receive(:call).with(
          hash_including(
            kind: "account_confirmation",
            recipient_role: :person,
            recipient_email: user.email,
            deliver: false
          )
        ).and_return(notification)

        described_class.confirmation_instructions(user, token).deliver_now
      end
    end

    context "when sending confirmation for email change (reconfirmation)" do
      before do
        user.skip_confirmation_notification!
        user.update!(email: "new@example.com")
      end

      it "creates an account_email_change_requested notification" do
        expect(NotificationServices::CreateNotification).to receive(:call).with(
          hash_including(
            kind: "account_email_change_requested",
            recipient_role: :person,
            recipient_email: user.unconfirmed_email,
            deliver: false
          )
        ).and_return(notification)

        described_class.confirmation_instructions(user, token).deliver_now
      end
    end

    context "when sending reset password instructions" do
      it "creates a reset_password notification and a reset_password_fyi" do
        expect(NotificationServices::CreateNotification).to receive(:call).with(
          hash_including(kind: "reset_password", recipient_role: :person, deliver: false)
        ).ordered.and_return(notification)

        expect(NotificationServices::CreateNotification).to receive(:call).with(
          hash_including(kind: "reset_password_fyi", recipient_role: :admin, deliver: true)
        ).ordered

        described_class.reset_password_instructions(user, token).deliver_now
      end
    end

    # unlock_instructions not tested here — app uses unlock_strategy: :none
    # so user_unlock_url route doesn't exist and the view can't render
  end
end
