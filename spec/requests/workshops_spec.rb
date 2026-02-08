require 'rails_helper'

RSpec.describe "/workshops", type: :request do
  # --- DESTROY ---------------------------------------------------------------
  describe "DELETE /destroy" do
    let(:user) { create(:user) }
    let(:admin) { create(:user, :admin) }
    let(:workshop) { create(:workshop, user: user) }

    context "when current_user is an admin" do
      before do
        sign_in admin
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

    context "when current_user is not an admin" do
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
        expect(flash[:alert]).to include("You are not authorized to perform this action")
      end

      it "does not destroy the workshop and redirects back from show page" do
        expect {
          delete workshop_path(workshop), headers: { "HTTP_REFERER" => workshop_path(workshop) }
        }.not_to change(Workshop, :count)

        expect(response).to redirect_to(workshop_path(workshop))
        follow_redirect!
        expect(flash[:alert]).to include("You are not authorized to perform this action")
      end

      it "does not destroy the workshop and redirects to root" do
        expect {
          delete workshop_path(workshop)
        }.not_to change(Workshop, :count)

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(flash[:alert]).to include("You are not authorized to perform this action")
      end
    end
  end
end
