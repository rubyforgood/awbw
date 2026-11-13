require "rails_helper"

RSpec.describe "Form submission search", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:submitter) { create(:person, first_name: "Quill", last_name: "Marlowe") }
  let(:form) { create(:form, name: "Bulk Payment Form") }
  let!(:submission) { create(:form_submission, form:, person: submitter) }
  let!(:other) { create(:form_submission) }

  describe "GET /search/form_submission" do
    context "as an admin" do
      before { sign_in admin }

      it "matches the submitter's name" do
        get "/search/form_submission", params: { q: "Marlowe" }

        json = response.parsed_body
        expect(json.map { |r| r["id"] }).to contain_exactly(submission.id)
        expect(json.first["label"]).to include("Bulk Payment Form", "Quill Marlowe", "(##{submission.id})")
      end

      it "matches the form's name" do
        get "/search/form_submission", params: { q: "Bulk Payment" }

        expect(response.parsed_body.map { |r| r["id"] }).to include(submission.id)
      end

      it "matches the submission's id" do
        get "/search/form_submission", params: { q: "##{other.id}" }

        expect(response.parsed_body.map { |r| r["id"] }).to include(other.id)
      end
    end

    it "forbids non-admins" do
      sign_in create(:user)

      get "/search/form_submission", params: { q: "Marlowe" }

      expect(response).not_to have_http_status(:ok)
    end
  end
end
