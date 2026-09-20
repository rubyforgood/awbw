require "rails_helper"

# The person edit page's combined comments & communications section is staged
# behind the profile-launch policy flip: PersonPolicy#edit? is admin-only for
# now and goes to admin || owner at launch. These specs simulate that flip to
# exercise the non-admin (owner) branch that lights up then, where only
# transactional emails (autoemail, non-bulk) are shown.
RSpec.describe "Owner view of communications on the person edit form", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  let!(:transactional_email) do
    create(:notification, noticeable: person, recipient_email: owner_user.email,
                          channel: "autoemail", kind: "form_submission_confirmation",
                          recipient_role: "person", email_subject: "We received your response")
  end

  let!(:bulk_email) do
    create(:notification, noticeable: person, recipient_email: owner_user.email,
                          channel: "autoemail", bulk: true, kind: "event_registration_reminder",
                          recipient_role: "person", email_subject: "Event reminder blast")
  end

  let!(:hand_logged_communication) do
    create(:notification, noticeable: person, recipient_email: owner_user.email,
                          channel: "phone", kind: "manual_log",
                          recipient_role: "person", email_subject: "Left a voicemail")
  end

  context "as the owner (simulating the profile-launch policy flip)" do
    before do
      sign_in owner_user
      allow_any_instance_of(PersonPolicy).to receive(:edit?).and_return(true)
    end

    it "shows transactional emails but hides bulk sends and hand-logged communications" do
      get edit_person_path(person)

      expect(response).to be_successful
      expect(response.body).to include("We received your response")
      expect(response.body).not_to include("Event reminder blast")
      expect(response.body).not_to include("Left a voicemail")
    end
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it "shows transactional, bulk, and hand-logged communications" do
      get edit_person_path(person)

      expect(response).to be_successful
      expect(response.body).to include("We received your response")
      expect(response.body).to include("Event reminder blast")
      expect(response.body).to include("Left a voicemail")
    end
  end
end
