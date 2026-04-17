require "rails_helper"

RSpec.describe "Notifications", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:notification) { create(:notification, recipient_email: regular_user.email) }

  describe "GET /notifications" do
    before { sign_in admin }

    let(:turbo_headers) { { "Turbo-Frame" => "notifications_results" } }
    let!(:story_notification) { create(:notification, noticeable: create(:story_idea), email_subject: "New story idea") }
    let!(:user_notification) { create(:notification, noticeable: create(:user), email_subject: "Welcome") }

    it "filters by email_topic" do
      matching = create(:notification, email_subject: "Confirm your new email address")
      get notifications_path, params: { email_topic: "User: confirm new email" }, headers: turbo_headers
      expect(response.body).to include(matching.recipient_email)
      expect(response.body).not_to include(story_notification.recipient_email)
    end

    it "filters by record_type" do
      get notifications_path, params: { record_type: "StoryIdea" }, headers: turbo_headers
      expect(response.body).to include(story_notification.recipient_email)
      expect(response.body).not_to include(user_notification.recipient_email)
    end

    it "wraps results in a turbo frame" do
      get notifications_path, headers: turbo_headers
      expect(response.body).to include('id="notifications_results"')
    end
  end

  describe "POST /notifications/:id/resend" do
    context "as an admin" do
      before { sign_in admin }

      it "creates a new notification with parent and root notification IDs" do
        # Force creation of the notification before the expect block
        notification_id = notification.id

        # Perform the action with jobs inline
        perform_enqueued_jobs do
          expect {
            post resend_notification_path(notification_id)
          }.to change(Notification, :count).by(1)
        end

        new_notification = Notification.last
        expect(new_notification.parent_notification_id).to eq(notification.id)
        expect(new_notification.root_notification_id).to eq(notification.id)
        expect(new_notification.kind).to eq(notification.kind)
        expect(new_notification.recipient_email).to eq(notification.recipient_email)
      end

      it "tracks resend chain correctly when resending a resent notification" do
        # Create first resend
        first_resend = nil
        perform_enqueued_jobs do
          post resend_notification_path(notification)
          first_resend = Notification.last
        end

        # Resend the resend
        perform_enqueued_jobs do
          expect {
            post resend_notification_path(first_resend)
          }.to change(Notification, :count).by(1)
        end

        second_resend = Notification.last
        expect(second_resend.parent_notification_id).to eq(first_resend.id)
        expect(second_resend.root_notification_id).to eq(notification.id)
      end

      it "calculates resend count correctly" do
        notification_id = notification.id

        # Create two resends
        perform_enqueued_jobs do
          post resend_notification_path(notification_id)
          post resend_notification_path(notification_id)
        end

        notification.reload
        expect(notification.resend_count).to eq(2)
      end

      it "sends the notification email" do
        perform_enqueued_jobs do
          expect {
            post resend_notification_path(notification)
          }.to change { ActionMailer::Base.deliveries.count }.by(1)
        end
      end

      it "updates the new notification with delivery details" do
        perform_enqueued_jobs do
          post resend_notification_path(notification)
        end

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

      it "denies resending Devise-originated notifications" do
        devise_notification = create(:notification, kind: "account_confirmation", recipient_email: regular_user.email)

        expect {
          post resend_notification_path(devise_notification)
        }.not_to change(Notification, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "does not allow resending" do
        # Force creation of the notification before the expect block
        notification_id = notification.id

        expect {
          post resend_notification_path(notification_id)
        }.not_to change(Notification, :count)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "as a guest" do
      it "redirects to new user session path" do
        post resend_notification_path(notification)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
