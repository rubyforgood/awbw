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

  describe "#confirmation_instructions" do
    context "when sending for initial signup (no pending reconfirmation)" do
      it "uses the welcome subject line" do
        mail = described_class.confirmation_instructions(user, token)

        expect(mail.subject).to eq("AWBW Portal: Welcome instructions for #{user.full_name}")
      end

      it "includes welcome copy and password setup CTA" do
        mail = described_class.confirmation_instructions(user, token)

        expect(mail.body.encoded).to include("Welcome to the AWBW Portal!")
        expect(mail.body.encoded).to include("Set your password")
      end
    end

    context "when sending for email change (reconfirmation)" do
      before do
        user.skip_confirmation_notification!
        user.update!(email: "new@example.com")
      end

      it "uses the email change subject line" do
        mail = described_class.confirmation_instructions(user, token)

        expect(mail.subject).to eq("AWBW Portal: Confirm your new email address")
      end

      it "includes email change copy instead of welcome copy" do
        mail = described_class.confirmation_instructions(user, token)

        expect(mail.body.encoded).to include("Confirm your new email")
        expect(mail.body.encoded).not_to include("Welcome to the AWBW Portal!")
        expect(mail.body.encoded).not_to include("Set your password")
      end

      it "shows the new email address in the body" do
        mail = described_class.confirmation_instructions(user, token)

        expect(mail.body.encoded).to include(user.unconfirmed_email)
      end
    end
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

  # Exercises the real CreateNotification (no stub) so these cover the persisted
  # Notification and the "From" name the communications pages render. Rails.env.test?
  # is stubbed per-example rather than in a before block so the user factories —
  # which fire Devise's on-create confirmation — don't log notifications of their own.
  describe "sender attribution" do
    let(:admin) { create(:user, first_name: "Dana", last_name: "Sender") }

    def unstub_notification_logging
      allow(Rails.env).to receive(:test?).and_return(false)
    end

    it "attributes an admin-sent invite to the admin" do
      invitee = create(:user, :unconfirmed)
      admin
      unstub_notification_logging

      expect {
        invitee.send_confirmation_instructions(sender: admin)
      }.to change(Notification, :count).by(1)

      expect(Notification.last.sender).to eq(admin)
      expect(Notification.last.decorate.sender_name).to eq("Dana Sender")
    end

    it "leaves an automated confirmation as the portal" do
      signup = create(:user, :unconfirmed)
      unstub_notification_logging

      expect {
        signup.send_confirmation_instructions
      }.to change(Notification, :count).by(1)

      expect(Notification.last.sender).to be_nil
      expect(Notification.last.decorate.sender_name).to eq(NotificationDecorator::PORTAL_SENDER_NAME)
    end

    it "leaves an automated password reset as the portal" do
      user
      unstub_notification_logging

      user.send_reset_password_instructions

      reset = Notification.where(kind: "reset_password").last
      expect(reset.sender).to be_nil
      expect(reset.decorate.sender_name).to eq(NotificationDecorator::PORTAL_SENDER_NAME)
    end
  end
end
