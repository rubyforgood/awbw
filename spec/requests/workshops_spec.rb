require 'rails_helper'

RSpec.describe "/workshops", type: :request do
  # --- SECTORS ---------------------------------------------------------------
  describe "sector saving via sector_ids" do
    let(:admin) { create(:user, :admin) }
    let!(:sector) { create(:sector, :published) }
    let!(:windows_type) { create(:windows_type) }

    before { sign_in admin }

    it "saves sectors via sector_ids on create" do
      post workshops_url, params: {
        workshop: {
          title: "Sector Test Workshop",
          windows_type_id: windows_type.id,
          category_ids: [""],
          sector_ids: ["", sector.id.to_s]
        }
      }

      expect(Workshop.last.sectors).to include(sector)
    end

    it "updates sectors via sector_ids on update" do
      workshop = create(:workshop)
      second_sector = create(:sector, :published)

      patch workshop_url(workshop), params: {
        workshop: {
          title: workshop.title,
          category_ids: [""],
          sector_ids: ["", second_sector.id.to_s]
        }
      }

      workshop.reload
      expect(workshop.sectors).to include(second_sector)
      expect(workshop.sectors).not_to include(sector)
    end
  end

  # --- DESTROY ---------------------------------------------------------------
  describe "DELETE /destroy" do
    let(:user) { create(:user) }
    let(:admin) { create(:user, :admin) }
    let(:workshop) { create(:workshop, created_by: user) }

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

      it "does not destroy the workshop and redirects to root" do
        expect {
          delete workshop_path(workshop), headers: { "HTTP_REFERER" => edit_workshop_path(workshop) }
        }.not_to change(Workshop, :count)

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(flash[:alert]).to include("You are not authorized to perform this action")
      end

      it "does not destroy the workshop and redirects to root" do
        expect {
          delete workshop_path(workshop), headers: { "HTTP_REFERER" => workshop_path(workshop) }
        }.not_to change(Workshop, :count)

        expect(response).to redirect_to(root_path)
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
