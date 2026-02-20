# frozen_string_literal: true

require "rails_helper"

# Tests the Dedupable concern through CategoriesController (richer config)
# and verifies it also works through SectorsController.
RSpec.describe "Dedupable concern", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let!(:category_type) { create(:category_type) }

  # ============================================================
  # CATEGORIES — full coverage of all 4 dedupe actions
  # ============================================================

  describe "Categories" do
    describe "GET dedupe_index" do
      context "as an admin" do
        before { sign_in admin }

        it "renders successfully" do
          get dedupe_index_categories_path
          expect(response).to have_http_status(:ok)
        end
      end

      context "as a regular user" do
        before { sign_in regular_user }

        it "denies access" do
          get dedupe_index_categories_path
          expect(response).to redirect_to(root_path)
        end
      end

      context "as a guest" do
        it "denies access" do
          get dedupe_index_categories_path
          expect(response).to redirect_to(root_path)
        end
      end
    end

    describe "GET dedupe_preview" do
      let!(:keep) { create(:category, name: "Keep Me", category_type: category_type, published: true) }
      let!(:delete_rec) { create(:category, name: "Delete Me", category_type: category_type, published: false) }

      context "as an admin" do
        before { sign_in admin }

        it "renders the preview page" do
          get dedupe_preview_categories_path(
            category_to_keep_id: keep.id,
            category_to_delete_id: delete_rec.id
          )
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Keep Me")
          expect(response.body).to include("Delete Me")
        end

        it "redirects when keep_id is missing" do
          get dedupe_preview_categories_path(
            category_to_delete_id: delete_rec.id
          )
          expect(response).to redirect_to(dedupe_index_categories_path)
        end

        it "redirects when delete_id is missing" do
          get dedupe_preview_categories_path(
            category_to_keep_id: keep.id
          )
          expect(response).to redirect_to(dedupe_index_categories_path)
        end

        it "redirects when both IDs are the same" do
          get dedupe_preview_categories_path(
            category_to_keep_id: keep.id,
            category_to_delete_id: keep.id
          )
          expect(response).to redirect_to(dedupe_index_categories_path)
          follow_redirect!
          expect(response.body).to include("two different")
        end

        it "redirects when a record is not found" do
          get dedupe_preview_categories_path(
            category_to_keep_id: keep.id,
            category_to_delete_id: 999_999
          )
          expect(response).to redirect_to(dedupe_index_categories_path)
          follow_redirect!
          expect(response.body).to include("not found")
        end
      end

      context "as a regular user" do
        before { sign_in regular_user }

        it "denies access" do
          get dedupe_preview_categories_path(
            category_to_keep_id: keep.id,
            category_to_delete_id: delete_rec.id
          )
          expect(response).to redirect_to(root_path)
        end
      end
    end

    describe "PATCH dedupe_update_keep" do
      let!(:keep) { create(:category, name: "Original", category_type: category_type, published: false) }

      context "as an admin" do
        before { sign_in admin }

        it "updates the record and returns 200" do
          patch dedupe_update_keep_categories_path,
                params: { id: keep.id, category_to_keep: { name: "Updated Name" } }

          expect(response).to have_http_status(:ok)
          expect(keep.reload.name).to eq("Updated Name")
        end

        it "updates published status" do
          patch dedupe_update_keep_categories_path,
                params: { id: keep.id, category_to_keep: { published: "1" } }

          expect(response).to have_http_status(:ok)
          expect(keep.reload.published).to be true
        end

        it "returns 422 on failure" do
          patch dedupe_update_keep_categories_path,
                params: { id: keep.id, category_to_keep: { name: "" } }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body).to have_key("error")
        end
      end

      context "as a regular user" do
        before { sign_in regular_user }

        it "denies access" do
          patch dedupe_update_keep_categories_path,
                params: { id: keep.id, category_to_keep: { name: "Nope" } }
          expect(response).to redirect_to(root_path)
          expect(keep.reload.name).to eq("Original")
        end
      end
    end

    describe "POST dedupe_execute" do
      let!(:keep) { create(:category, name: "Keeper", category_type: category_type, published: true) }
      let!(:delete_rec) { create(:category, name: "Duplicate", category_type: category_type, published: false) }
      let!(:workshop) { create(:workshop) }
      let!(:tagging) { create(:categorizable_item, category: delete_rec, categorizable: workshop) }

      context "as an admin" do
        before { sign_in admin }

        it "merges and redirects with success notice" do
          post dedupe_execute_categories_path, params: {
            category_to_delete_id: delete_rec.id,
            category_to_keep_id: keep.id
          }

          expect(response).to redirect_to(categories_path)
          follow_redirect!
          expect(response.body).to include("merged successfully")
        end

        it "deletes the duplicate record" do
          expect {
            post dedupe_execute_categories_path, params: {
              category_to_delete_id: delete_rec.id,
              category_to_keep_id: keep.id
            }
          }.to change(Category, :count).by(-1)

          expect(Category.exists?(keep.id)).to be true
          expect(Category.exists?(delete_rec.id)).to be false
        end

        it "moves taggings to the keeper" do
          post dedupe_execute_categories_path, params: {
            category_to_delete_id: delete_rec.id,
            category_to_keep_id: keep.id
          }

          expect(CategorizableItem.where(category_id: keep.id).count).to eq(1)
          expect(CategorizableItem.where(category_id: delete_rec.id).count).to eq(0)
        end

        it "updates the keeper before merging when keep params provided" do
          post dedupe_execute_categories_path, params: {
            category_to_delete_id: delete_rec.id,
            category_to_keep_id: keep.id,
            category_to_keep: { name: "Better Name" }
          }

          expect(keep.reload.name).to eq("Better Name")
        end

        it "redirects to dedupe_index on error" do
          post dedupe_execute_categories_path, params: {
            category_to_delete_id: 999_999,
            category_to_keep_id: keep.id
          }

          expect(response).to redirect_to(dedupe_index_categories_path)
          follow_redirect!
          expect(response.body).to include("Error merging")
        end
      end

      context "as a regular user" do
        before { sign_in regular_user }

        it "denies access and does not merge" do
          expect {
            post dedupe_execute_categories_path, params: {
              category_to_delete_id: delete_rec.id,
              category_to_keep_id: keep.id
            }
          }.not_to change(Category, :count)

          expect(response).to redirect_to(root_path)
        end
      end
    end
  end

  # ============================================================
  # SECTORS — verify the concern works for a second model
  # ============================================================

  describe "Sectors" do
    describe "GET dedupe_index" do
      before { sign_in admin }

      it "renders successfully" do
        get dedupe_index_sectors_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET dedupe_preview" do
      before { sign_in admin }

      let!(:keep) { create(:sector, name: "Keep Sector", published: true) }
      let!(:delete_rec) { create(:sector, name: "Delete Sector", published: false) }

      it "renders the preview page" do
        get dedupe_preview_sectors_path(
          sector_to_keep_id: keep.id,
          sector_to_delete_id: delete_rec.id
        )
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Keep Sector")
      end

      it "redirects when a record is not found" do
        get dedupe_preview_sectors_path(
          sector_to_keep_id: keep.id,
          sector_to_delete_id: 999_999
        )
        expect(response).to redirect_to(dedupe_index_sectors_path)
      end
    end

    describe "PATCH dedupe_update_keep" do
      before { sign_in admin }

      let!(:keep) { create(:sector, name: "Original Sector", published: false) }

      it "updates the record" do
        patch dedupe_update_keep_sectors_path,
              params: { id: keep.id, sector_to_keep: { name: "Updated Sector" } }

        expect(response).to have_http_status(:ok)
        expect(keep.reload.name).to eq("Updated Sector")
      end
    end

    describe "POST dedupe_execute" do
      before { sign_in admin }

      let!(:keep) { create(:sector, name: "Keep Sector", published: true) }
      let!(:delete_rec) { create(:sector, name: "Dup Sector", published: false) }
      let!(:workshop) { create(:workshop) }
      let!(:tagging) { create(:sectorable_item, sector: delete_rec, sectorable: workshop) }

      it "merges and redirects with success notice" do
        expect {
          post dedupe_execute_sectors_path, params: {
            sector_to_delete_id: delete_rec.id,
            sector_to_keep_id: keep.id
          }
        }.to change(Sector, :count).by(-1)

        expect(response).to redirect_to(sectors_path)
        expect(SectorableItem.where(sector_id: keep.id).count).to eq(1)
      end
    end
  end
end
