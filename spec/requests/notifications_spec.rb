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

    it "shows the email param in the Email contains box" do
      get notifications_path, params: { email: "kim.davis@gmail.com" }
      value = Nokogiri::HTML(response.body).at_css('input[name="email"]')&.[]("value")
      expect(value).to eq("kim.davis@gmail.com")
    end

    context "back eyebrow" do
      it "links to the originating record when arrived from it" do
        person = create(:person, first_name: "Umberto", last_name: "User")
        get notifications_path(return_to_type: "Person", return_to_id: person.id)

        expect(response.body).to include(edit_person_path(person))
        expect(response.body).to include("Umberto User")
      end

      it "falls back to admin home when reached directly" do
        get notifications_path
        expect(response.body).to include("Admin home")
      end

      it "ignores an unrecognized return_to_type" do
        get notifications_path(return_to_type: "User", return_to_id: user_notification.id)
        expect(response.body).to include("Admin home")
      end
    end

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

  describe "GET /notifications/new" do
    context "as an admin" do
      before { sign_in admin }

      it "renders the new communication form" do
        get new_notification_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("New communication")
        expect(response.body).to include("Search people by name or email")
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "is not authorized" do
        get new_notification_path

        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        get new_notification_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /notifications" do
    let(:person) { create(:person, email: "logged@example.com") }
    let(:valid_params) do
      {
        person_id: person.id,
        notification: {
          channel: "phone",
          email_subject: "Called about registration",
          email_body_text: "Left a voicemail."
        }
      }
    end

    context "as an admin" do
      before { sign_in admin }

      it "logs a manual communication against the person, attributed to the sender" do
        expect {
          post notifications_path, params: valid_params
        }.to change(Notification, :count).by(1)

        notification = Notification.last
        expect(notification.noticeable).to eq(person)
        expect(notification.recipient_email).to eq(person.communications_email)
        expect(notification.sender).to eq(admin)
        expect(notification.channel).to eq("phone")
        expect(notification.email_subject).to eq("Called about registration")
        expect(notification.kind).to eq("manual_log")
        expect(response).to redirect_to(notifications_path)
      end

      it "defaults a logged communication to outgoing" do
        post notifications_path, params: valid_params
        expect(Notification.last.direction).to eq("outgoing")
      end

      it "logs an incoming communication when the direction is set" do
        post notifications_path, params: valid_params.deep_merge(notification: { direction: "incoming" })
        expect(Notification.last).to be_incoming
      end

      it "re-renders with an error when no person is selected" do
        expect {
          post notifications_path, params: valid_params.except(:person_id)
        }.not_to change(Notification, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Select a person")
      end

      it "re-renders when the subject is blank" do
        expect {
          post notifications_path, params: valid_params.deep_merge(notification: { email_subject: "" })
        }.not_to change(Notification, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "is not authorized and creates nothing" do
        expect {
          post notifications_path, params: valid_params
        }.not_to change(Notification, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        post notifications_path, params: valid_params

        expect(response).to redirect_to(new_user_session_path)
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

      # Scoped to the From row's <dd> so an unrelated mention of the sender or of
      # "AWBW Portal" elsewhere on the page can't satisfy (or break) the assertion.
      def from_row(body)
        Capybara.string(body).find(:xpath, "//dt[normalize-space()='From']/following-sibling::dd[1]")
      end

      def to_row(body)
        Capybara.string(body).find(:xpath, "//dt[normalize-space()='To']/following-sibling::dd[1]")
      end

      it "names the sending person in the From row when a sender is set" do
        sender = create(:user, :admin, first_name: "Dana", last_name: "Sender")
        sent = create(:notification, kind: "event_registration_reminder", sender: sender)

        get notification_path(sent)

        expect(from_row(response.body)).to have_text("Dana Sender")
      end

      it "shows AWBW Portal in the From row for automated messages with no sender" do
        automated = create(:notification, kind: "account_confirmation", sender: nil)

        get notification_path(automated)

        expect(from_row(response.body)).to have_text("AWBW Portal")
      end

      it "flips From/To for an incoming communication — the person sent it to the author" do
        author = create(:user, :admin, first_name: "Dana", last_name: "Sender")
        incoming = create(:notification, :incoming, kind: "manual_log", channel: "phone",
                          email_subject: "They called us", sender: author, recipient_email: "kim@example.com")

        get notification_path(incoming)

        expect(from_row(response.body)).to have_text("kim@example.com")
        expect(to_row(response.body)).to have_text("Dana Sender")
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

      it "attributes the resent copy to the admin who resent it" do
        post resend_notification_path(notification.id)

        expect(Notification.last.sender).to eq(admin)
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
