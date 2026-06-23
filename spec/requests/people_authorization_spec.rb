require "rails_helper"

RSpec.describe "People authorization", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user, :with_person) }
  let(:other_person) { create(:person) }

  describe "GET /people" do
    context "as a visitor" do
      it "redirects to new user session path" do
        get people_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get people_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "renders successfully" do
        get people_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /people/:id" do
    context "as a visitor" do
      it "redirects to new user session path" do
        get person_path(other_person)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "redirects to root for another person" do
        get person_path(other_person)
        expect(response).to redirect_to(root_path)
      end

      it "renders successfully for own person" do
        get person_path(regular_user.person)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "renders successfully" do
        get person_path(other_person)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /people/:id show page content" do
    context "as an admin" do
      before do
        sign_in admin
        get person_path(other_person)
      end

      it "shows the Edit link" do
        expect(response.body).to include("Edit")
      end

      it "shows email with admin-only styling when profile_show_email is off" do
        other_person.update!(profile_show_email: false)
        get person_path(other_person)
        email = other_person.user&.email || other_person.email
        expect(response.body).to include("admin-only")
        expect(response.body).to include(email) if email.present?
      end

      it "shows the Submitted content section" do
        expect(response.body).to include("Submitted content")
      end

      it "does not show the Comments section" do
        expect(response.body).not_to include("comment_form")
      end

      it "shows the mailing list consent status" do
        expect(response.body).to include("No consent on file")
      end
    end

    context "as the owner" do
      before do
        sign_in regular_user
        get person_path(regular_user.person)
      end

      it "does not show the Edit link" do
        expect(response.body).not_to include(edit_person_path(regular_user.person))
      end

      it "shows the Submitted content section" do
        expect(response.body).to include("Submitted content")
      end

      it "hides the mailing list consent status from the owner" do
        expect(response.body).not_to include("No consent on file")
      end
    end
  end

  describe "GET /people/:id/edit" do
    context "as the owner" do
      before { sign_in regular_user }

      it "redirects to root" do
        get edit_person_path(regular_user.person)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "renders successfully" do
        get edit_person_path(other_person)
        expect(response).to have_http_status(:ok)
      end

      it "shows the racial/ethnic identity field" do
        get edit_person_path(other_person)
        expect(response.body).to include("person[racial_ethnic_identity]")
      end

      it "shows the FileMaker code field" do
        get edit_person_path(other_person)
        expect(response.body).to include("person[filemaker_code]")
      end
    end
  end

  describe "PATCH /people/:id" do
    context "as the owner" do
      before { sign_in regular_user }

      it "redirects to root" do
        patch person_path(regular_user.person), params: { person: { first_name: "Changed" } }
        expect(response).to redirect_to(root_path)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "updates the person" do
        patch person_path(other_person), params: { person: { first_name: "Updated" } }
        expect(response).to redirect_to(person_path(other_person))
        expect(other_person.reload.first_name).to eq("Updated")
      end

      it "updates the racial/ethnic identity" do
        patch person_path(other_person), params: { person: { racial_ethnic_identity: "Asian" } }
        expect(other_person.reload.racial_ethnic_identity).to eq("Asian")
      end

      it "updates the FileMaker code" do
        patch person_path(other_person), params: { person: { filemaker_code: "FM-123" } }
        expect(other_person.reload.filemaker_code).to eq("FM-123")
      end

      it "withdraws mailing list consent when the box is unchecked" do
        other_person.update!(mailing_list_consent_at: Time.current, mailing_list_consent_source: "Registration: X")

        patch person_path(other_person), params: { person: { mailing_list_consented: "0" } }

        expect(other_person.reload.mailing_list_consent_at).to be_nil
        expect(other_person.mailing_list_consent_source).to be_nil
      end

      it "records mailing list consent when the box is checked" do
        patch person_path(other_person), params: { person: { mailing_list_consented: "1" } }

        expect(other_person.reload.mailing_list_consent_at).to be_present
      end
    end
  end
end
