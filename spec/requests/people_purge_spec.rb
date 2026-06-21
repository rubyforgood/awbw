require "rails_helper"

RSpec.describe "People purge", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user, :with_person) }
  let!(:person) { create(:person, user: nil) }
  let!(:submission) { create(:form_submission, person: person) }

  describe "GET /people/:id/purge_confirmation (preview)" do
    context "as an admin" do
      before { sign_in admin }

      it "shows the inventory and a delete button for a fake person" do
        get purge_confirmation_person_path(person)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("What will be deleted")
        expect(response.body).to include("Permanently delete")
      end

      it "shows the inventory and an override (not a direct delete) for a real person" do
        real = create(:person) # factory gives them a User account
        get purge_confirmation_person_path(real)

        expect(response.body).to include("looks real")
        expect(response.body).to include("What will be deleted")
        expect(response.body).to include("Delete anyway")
        expect(response.body).not_to include("Permanently delete")
      end

      it "shows the override warning and a delete button for a real person when force=true" do
        real = create(:person)
        get purge_confirmation_person_path(real, force: true)

        expect(response.body).to include("Override")
        expect(response.body).to include("Permanently delete")
      end

      it "shows blocking content and no delete button when the account authored content" do
        real = create(:person)
        create(:workshop, created_by: real.user)

        get purge_confirmation_person_path(real, force: true)

        expect(response.body).to include("Cannot delete")
        expect(response.body).to include("Workshops")
        expect(response.body).not_to include("Permanently delete")
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "is forbidden" do
        get purge_confirmation_person_path(person)
        expect(response).not_to have_http_status(:ok)
      end
    end
  end

  describe "DELETE /people/:id/purge" do
    context "as an admin" do
      before { sign_in admin }

      it "deletes the fake person and their data" do
        delete purge_person_path(person)

        expect(response).to redirect_to(people_path)
        expect(Person.exists?(person.id)).to be false
        expect(FormSubmission.exists?(submission.id)).to be false
      end

      it "skips a person who looks real and redirects back with an alert" do
        real = create(:person)
        delete purge_person_path(real)

        expect(response).to redirect_to(edit_person_path(real))
        expect(flash[:alert]).to be_present
        expect(Person.exists?(real.id)).to be true
      end

      it "deletes a person who looks real when force=true" do
        real = create(:person)
        real.user.update!(super_user: true)

        delete purge_person_path(real, force: true)

        expect(response).to redirect_to(people_path)
        expect(Person.exists?(real.id)).to be false
      end

      it "fails gracefully when the account owns FK-restricted content" do
        real = create(:person)
        create(:workshop, created_by: real.user)

        delete purge_person_path(real, force: true)

        expect(response).to redirect_to(edit_person_path(real))
        expect(flash[:alert]).to include("reassigned or removed")
        expect(Person.exists?(real.id)).to be true
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "is forbidden and does not delete" do
        delete purge_person_path(person)

        expect(response).not_to have_http_status(:ok)
        expect(Person.exists?(person.id)).to be true
      end
    end

    context "as a visitor" do
      it "redirects to sign in" do
        delete purge_person_path(person)

        expect(response).to redirect_to(new_user_session_path)
        expect(Person.exists?(person.id)).to be true
      end
    end
  end

  describe "the edit-page button" do
    before { sign_in admin }

    it "appears only when admin=true is in the query" do
      get edit_person_path(person, admin: "true")
      expect(response.body).to include("Delete person &amp; all data")

      get edit_person_path(person)
      expect(response.body).not_to include("Delete person &amp; all data")
    end
  end
end
