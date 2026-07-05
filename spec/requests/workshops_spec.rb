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
          category_ids: [ "" ],
          sector_ids: [ "", sector.id.to_s ]
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
          category_ids: [ "" ],
          sector_ids: [ "", second_sector.id.to_s ]
        }
      }

      workshop.reload
      expect(workshop.sectors).to include(second_sector)
      expect(workshop.sectors).not_to include(sector)
    end
  end

  # --- SECTOR FILTER LABELS --------------------------------------------------
  describe "sector filter dropdown labels" do
    let(:admin) { create(:user, :admin) }
    let!(:sector) { create(:sector, :published, name: "LGBTQIA+") }

    before { sign_in admin }

    it "renders sector names with their canonical casing, not sentence case" do
      get workshops_url

      expect(response.body).to include("LGBTQIA+")
      expect(response.body).not_to include("Lgbtqia+")
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

  # --- RECORD NOT UNIQUE HANDLING -----------------------------------------------
  describe "author crediting" do
    let(:admin) { create(:user, :admin) }
    let!(:windows_type) { create(:windows_type) }

    before { sign_in admin }

    it "records the current user as created_by regardless of the submitted value" do
      someone_else = create(:user)
      post workshops_url, params: {
        workshop: { title: "Audit Workshop", windows_type_id: windows_type.id,
                    category_ids: [ "" ], created_by_id: someone_else.id }
      }

      expect(Workshop.last.created_by).to eq(admin)
    end

    it "assigns the chosen person as author" do
      facilitator = create(:person)
      post workshops_url, params: {
        workshop: { title: "Authored Workshop", windows_type_id: windows_type.id,
                    category_ids: [ "" ], author_id: facilitator.id }
      }

      expect(Workshop.last.author).to eq(facilitator)
    end
  end

  describe "RecordNotUnique handling" do
    let(:admin) { create(:user, :admin) }

    before { sign_in admin }

    describe "POST /create" do
      it "handles RecordNotUnique gracefully" do
        allow_any_instance_of(Workshop).to receive(:save).and_raise(
          ActiveRecord::RecordNotUnique.new("Duplicate entry")
        )

        expect {
          post workshops_url, params: {
            workshop: { title: "Test Workshop", category_ids: [ "" ] }
          }
        }.not_to change(Workshop, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Unable to save the workshop")
      end
    end

    describe "PATCH /update" do
      it "handles RecordNotUnique gracefully" do
        workshop = create(:workshop)

        allow_any_instance_of(Workshop).to receive(:save).and_raise(
          ActiveRecord::RecordNotUnique.new("Duplicate entry")
        )

        patch workshop_url(workshop), params: {
          workshop: { title: "Updated Title", category_ids: [ "" ] }
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Unable to update the workshop")
      end
    end
  end
end
