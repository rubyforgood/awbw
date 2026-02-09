require "rails_helper"

RSpec.describe "Notifications", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:notification) { create(:notification, recipient_email: regular_user.email) }

  describe "POST /notifications/:id/resend" do
    context "as an admin" do
      before { sign_in admin }

      it "creates a new notification with resend flag" do
        expect {
          post resend_notification_path(notification)
        }.to change(Notification, :count).by(1)

        new_notification = Notification.last
        expect(new_notification.resend).to be true
        expect(new_notification.kind).to eq(notification.kind)
        expect(new_notification.recipient_email).to eq(notification.recipient_email)
      end

      it "sends the notification email" do
        expect {
          post resend_notification_path(notification)
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "updates the new notification with delivery details" do
        post resend_notification_path(notification)

        new_notification = Notification.last
        expect(new_notification.delivered_at).to be_present
        expect(new_notification.email_subject).to be_present
      end

      it "redirects to the original notification with success message" do
        post resend_notification_path(notification)

        expect(response).to redirect_to(notification_path(notification))
        follow_redirect!
        expect(response.body).to include("Notification email has been resent successfully")
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "does not allow resending" do
        expect {
          post resend_notification_path(notification)
        }.not_to change(Notification, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        post resend_notification_path(notification)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
