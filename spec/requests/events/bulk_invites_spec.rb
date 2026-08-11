require "rails_helper"

# The bulk reminder page gains an invite mode (?mode=invite) that sends the portal
# welcome email to registrants with no account yet. The email is fixed — the admin
# can only preview it, not edit a subject/message.
RSpec.describe "Events::BulkInvites", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }
  let!(:no_account) do
    create(:event_registration, event: event,
      registrant: create(:person, user: nil, email: "newbie@example.com", first_name: "Newbie", last_name: "One"))
  end
  let!(:has_account) do
    create(:event_registration, event: event,
      registrant: create(:person, first_name: "Existing", last_name: "Two"))
  end

  before { sign_in admin }

  def checked?(body, registration)
    node = Nokogiri::HTML(body).at_css("#registration_ids_#{registration.id}")
    node.present? && node["checked"].present?
  end

  describe "the invite picker" do
    it "lists only registrants with no portal account, pre-checked" do
      get preview_reminder_event_path(event, mode: "invite")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Send login invites")
      expect(response.body).to include("Newbie One")
      expect(response.body).not_to include("Existing Two")
      expect(checked?(response.body, no_account)).to be(true)
    end

    it "previews the fixed invite email and hides the editable subject/message" do
      get preview_reminder_event_path(event, mode: "invite")

      expect(response.body).to include("Welcome to the AWBW Portal!")
      expect(response.body).to include("can't be edited")
      # No editable draft fields in invite mode.
      expect(response.body).not_to include('name="custom_message"')
      expect(response.body).not_to include('name="custom_subject"')
    end
  end

  describe "confirm interstitial" do
    it "shows the invite email without sending" do
      expect {
        post confirm_reminder_event_path(event), params: { mode: "invite", registration_ids: [ no_account.id ] }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Send login invites")
      expect(response.body).to include("Welcome instructions for Newbie One")
    end
  end

  describe "sending invites" do
    it "creates an account for each recipient and sends the invite email" do
      expect {
        post send_reminder_event_path(event), params: { mode: "invite", registration_ids: [ no_account.id ] }
      }.to change { no_account.registrant.reload.user }.from(nil)
        .and change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to redirect_to(registrants_event_path(event))
      expect(flash[:notice]).to include("Login invites")
    end

    it "attributes the invite to the admin who sent it" do
      post send_reminder_event_path(event), params: { mode: "invite", registration_ids: [ no_account.id ] }

      user = no_account.registrant.reload.user
      expect(user.welcome_instructions_sent_by).to eq(admin)
    end

    it "redirects back to the picker when nothing is selected" do
      post send_reminder_event_path(event), params: { mode: "invite", registration_ids: [] }

      expect(response).to redirect_to(preview_reminder_event_path(event, mode: "invite", custom_message: "", custom_subject: ""))
      expect(flash[:alert]).to be_present
    end
  end
end
