require "rails_helper"

RSpec.describe "Notifications", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:notification) { create(:notification, recipient_email: regular_user.email) }

  describe "GET /communications (friendly alias)" do
    before { sign_in admin }

    it "redirects to /notifications" do
      get "/communications"
      expect(response).to redirect_to("/notifications")
    end

    it "preserves filter params on the redirect" do
      get "/communications", params: { email: "kim" }
      expect(response).to redirect_to("/notifications?email=kim")
    end
  end

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

    context "filtering by responded_status" do
      let!(:fyi_responded)     { create(:notification, kind: "contact_us_fyi", responded: true,  recipient_email: "yes-fyi@example.com") }
      let!(:fyi_not_responded) { create(:notification, kind: "contact_us_fyi", responded: false, recipient_email: "no-fyi@example.com") }
      let!(:user_confirmation) { create(:notification, kind: "contact_us",                       recipient_email: "confirm@example.com") }

      it "yes returns only responded contact_us_fyi notifications" do
        get notifications_path, params: { responded_status: "yes" }, headers: turbo_headers
        expect(response.body).to include(fyi_responded.recipient_email)
        expect(response.body).not_to include(fyi_not_responded.recipient_email)
        expect(response.body).not_to include(user_confirmation.recipient_email)
      end

      it "no returns only unresponded contact_us_fyi notifications" do
        get notifications_path, params: { responded_status: "no" }, headers: turbo_headers
        expect(response.body).to include(fyi_not_responded.recipient_email)
        expect(response.body).not_to include(fyi_responded.recipient_email)
        expect(response.body).not_to include(user_confirmation.recipient_email)
      end

      it "na excludes contact_us_fyi notifications" do
        get notifications_path, params: { responded_status: "na" }, headers: turbo_headers
        expect(response.body).to include(user_confirmation.recipient_email)
        expect(response.body).not_to include(fyi_responded.recipient_email)
        expect(response.body).not_to include(fyi_not_responded.recipient_email)
      end
    end

    it "wraps results in a turbo frame" do
      get notifications_path, headers: turbo_headers
      expect(response.body).to include('id="notifications_results"')
    end

    it "links a form submission noticeable to its show page" do
      submission = create(:form_submission)
      create(:notification, noticeable: submission, recipient_email: "bulk-payer@example.com")

      get notifications_path, headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("bulk-payer@example.com")
      expect(response.body).to include(form_submission_path(submission))
    end

    context "responded checkbox rendering" do
      let!(:fyi)             { create(:notification, kind: "contact_us_fyi", responded: false, recipient_email: "fyi@example.com") }
      let!(:fyi_done)        { create(:notification, kind: "contact_us_fyi", responded: true,  recipient_email: "done@example.com") }
      let!(:user_confirm)    { create(:notification, kind: "contact_us",                      recipient_email: "confirm@example.com") }
      let!(:other)           { create(:notification, kind: "reset_password_fyi",              recipient_email: "other@example.com") }

      it "renders an unchecked checkbox for unresponded contact_us_fyi rows" do
        get notifications_path, params: { email: "fyi@example.com" }, headers: turbo_headers

        expect(response.body).to match(/name="notification\[responded\]"[^>]*value="1"(?![^>]*checked)/)
      end

      it "renders a checked checkbox for responded contact_us_fyi rows" do
        get notifications_path, params: { email: "done@example.com" }, headers: turbo_headers

        expect(response.body).to match(/name="notification\[responded\]"[^>]*value="1"[^>]*checked/)
      end

      it "renders an em-dash placeholder (no checkbox) for contact_us auto-confirmations" do
        get notifications_path, params: { email: "confirm@example.com" }, headers: turbo_headers

        expect(response.body).to include(user_confirm.recipient_email)
        expect(response.body).not_to match(/<input[^>]*name="notification\[responded\]"/)
      end

      it "renders an em-dash placeholder (no checkbox) for other kinds" do
        get notifications_path, params: { email: "other@example.com" }, headers: turbo_headers

        expect(response.body).to include(other.recipient_email)
        expect(response.body).not_to match(/<input[^>]*name="notification\[responded\]"/)
      end
    end
  end

  describe "GET /notifications/:id" do
    let(:fyi)          { create(:notification, kind: "contact_us_fyi") }
    let(:user_confirm) { create(:notification, kind: "contact_us") }
    let(:other)        { create(:notification, kind: "reset_password_fyi") }

    context "as an admin" do
      before { sign_in admin }

      it "renders the responded checkbox for contact_us_fyi" do
        get notification_path(fyi)

        expect(response.body).to match(/<input[^>]*name="notification\[responded\]"[^>]*value="1"/)
      end

      it "does not render the responded checkbox for contact_us (auto-confirmation)" do
        get notification_path(user_confirm)

        expect(response.body).not_to match(/<input[^>]*name="notification\[responded\]"/)
      end

      it "does not render the responded checkbox for other kinds" do
        get notification_path(other)

        expect(response.body).not_to match(/<input[^>]*name="notification\[responded\]"/)
      end
    end

    context "as a non-admin owner" do
      let(:fyi) { create(:notification, kind: "contact_us_fyi", recipient_email: regular_user.email) }

      before { sign_in regular_user }

      it "does not render the responded checkbox even on contact_us_fyi" do
        get notification_path(fyi)

        expect(response.body).not_to match(/<input[^>]*name="notification\[responded\]"/)
      end
    end
  end

  describe "PATCH /notifications/:id" do
    let(:contact_notification) { create(:notification, kind: "contact_us_fyi", recipient_email: regular_user.email) }

    context "as an admin" do
      before { sign_in admin }

      it "marks the notification as responded" do
        patch notification_path(contact_notification), params: { notification: { responded: "1" } }

        expect(response).to have_http_status(:ok)
        expect(contact_notification.reload.responded).to be(true)
      end

      it "marks the notification as not responded" do
        contact_notification.update!(responded: true)

        patch notification_path(contact_notification), params: { notification: { responded: "0" } }

        expect(response).to have_http_status(:ok)
        expect(contact_notification.reload.responded).to be(false)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "does not allow updating" do
        patch notification_path(contact_notification), params: { notification: { responded: "1" } }

        expect(contact_notification.reload.responded).to be(false)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        patch notification_path(contact_notification), params: { notification: { responded: "1" } }

        expect(response).to redirect_to(new_user_session_path)
      end
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
        expect(response.body).to include("Communication has been resent successfully")
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
