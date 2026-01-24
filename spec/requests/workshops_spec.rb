require 'rails_helper'

RSpec.describe "/workshops", type: :request do
  # --- DESTROY ---------------------------------------------------------------
  describe "DELETE /destroy" do
    let(:user) { create(:user) }
    let(:super_user) { create(:user, super_user: true) }
    let(:workshop) { create(:workshop, user: user) }

    context "when current_user is a super_user" do
      before do
        sign_in super_user
        workshop  # Ensure workshop is persisted before the test
      end

      it "destroys the workshop and redirects to workshops_path" do
        expect {
          delete workshop_path(workshop)
        }.to change(Workshop, :count).by(-1)

        expect(response).to redirect_to(workshops_path)
        follow_redirect!
        expect(response.body).to include("Workshop was successfully destroyed.")
      end
    end

    context "when current_user is not a super_user" do
      before do
        sign_in user
        workshop  # Ensure workshop is persisted before the test
      end

      it "does not destroy the workshop and redirects back from edit page" do
        expect {
          delete workshop_path(workshop), headers: { "HTTP_REFERER" => edit_workshop_path(workshop) }
        }.not_to change(Workshop, :count)

        expect(response).to redirect_to(edit_workshop_path(workshop))
        follow_redirect!
        expect(response.body).to include("You do not have permission to delete a workshop")
      end

      it "does not destroy the workshop and redirects back from show page" do
        expect {
          delete workshop_path(workshop), headers: { "HTTP_REFERER" => workshop_path(workshop) }
        }.not_to change(Workshop, :count)

        expect(response).to redirect_to(workshop_path(workshop))
        follow_redirect!
        expect(response.body).to include("You do not have permission to delete a workshop")
      end

      it "does not destroy the workshop and redirects to workshops_path as fallback" do
        expect {
          delete workshop_path(workshop)
        }.not_to change(Workshop, :count)

        expect(response).to redirect_to(workshops_path)
        follow_redirect!
        expect(response.body).to include("You do not have permission to delete a workshop")
      end
    end
  end
end
