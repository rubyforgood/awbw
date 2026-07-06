require "rails_helper"

RSpec.describe "Events::FormSubmissions", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }
  let(:person) { create(:person) }
  let(:form) { create(:form) }
  let!(:submission) do
    create(:form_submission, person: person, form: form, event: event)
  end

  describe "GET /events/:event_id/form_submissions/:person_id" do
    context "as admin" do
      before { sign_in admin }

      it "shows the person's form submissions for the event" do
        get event_registrant_submissions_path(event, person_id: person.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(person.name)
        expect(response.body).to include(form.name)
      end

      it "returns 404 when person does not exist" do
        get event_registrant_submissions_path(event, person_id: 999999)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "as non-admin" do
      before { sign_in create(:user) }

      it "redirects" do
        get event_registrant_submissions_path(event, person_id: person.id)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as unauthenticated" do
      it "redirects to sign in" do
        get event_registrant_submissions_path(event, person_id: person.id)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
