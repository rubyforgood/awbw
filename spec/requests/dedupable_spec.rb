# frozen_string_literal: true

require "rails_helper"

# Tests the Dedupable concern through CategoriesController (richer config)
# and verifies it also works through SectorsController.
RSpec.describe "Dedupable concern", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let!(:category_type) { create(:category_type) }

  # Helper to create duplicate records bypassing uniqueness validation
  def create_category(name:, **attrs)
    record = build(:category, name: name, category_type: category_type, **attrs)
    record.save!(validate: false)
    record
  end

  def create_sector(name:, **attrs)
    record = build(:sector, name: name, **attrs)
    record.save!(validate: false)
    record
  end

  def create_workshop(title:, **attrs)
    record = build(:workshop, title: title, **attrs)
    record.save!(validate: false)
    record
  end

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

        it "finds duplicate groups" do
          create_category(name: "Duplicate")
          create_category(name: "duplicate")
          create(:category, name: "Unique", category_type: category_type)

          get dedupe_index_categories_path
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Duplicate")
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
      let!(:delete_rec) { create_category(name: "Delete Me", published: false) }

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

        it "ignores blank values and does not overwrite existing data" do
          patch dedupe_update_keep_categories_path,
                params: { id: keep.id, category_to_keep: { name: "" } }

          expect(response).to have_http_status(:ok)
          expect(keep.reload.name).to eq("Original")
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
      let!(:delete_rec) { create_category(name: "Duplicate", published: false) }
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
        create_sector(name: "Dup Sector")
        create_sector(name: "dup sector")

        get dedupe_index_sectors_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET dedupe_preview" do
      before { sign_in admin }

      let!(:keep) { create(:sector, name: "Keep Sector", published: true) }
      let!(:delete_rec) { create_sector(name: "Delete Sector", published: false) }

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
      let!(:delete_rec) { create_sector(name: "Dup Sector", published: false) }
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

  # ============================================================
  # WORKSHOPS — verify concern works with name_column: :title
  # ============================================================

  describe "Workshops" do
    describe "GET dedupe_index" do
      before { sign_in admin }

      it "renders successfully" do
        create_workshop(title: "Dup Workshop")
        create_workshop(title: "dup workshop")

        get dedupe_index_workshops_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Dup Workshop")
      end
    end

    describe "GET dedupe_preview" do
      before { sign_in admin }

      let!(:keep) { create(:workshop, title: "Keep Workshop", published: true) }
      let!(:delete_rec) { create_workshop(title: "Delete Workshop", published: false) }

      it "renders the preview page" do
        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: delete_rec.id
        )
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Keep Workshop")
        expect(response.body).to include("Delete Workshop")
      end

      it "redirects when both IDs are the same" do
        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: keep.id
        )
        expect(response).to redirect_to(dedupe_index_workshops_path)
        follow_redirect!
        expect(response.body).to include("two different")
      end
    end

    describe "PATCH dedupe_update_keep" do
      before { sign_in admin }

      let!(:keep) { create(:workshop, title: "Original Workshop", published: false) }

      it "updates the record" do
        patch dedupe_update_keep_workshops_path,
              params: { id: keep.id, workshop_to_keep: { title: "Updated Workshop" } }

        expect(response).to have_http_status(:ok)
        expect(keep.reload.title).to eq("Updated Workshop")
      end

      it "updates rich text fields" do
        patch dedupe_update_keep_workshops_path,
              params: { id: keep.id, workshop_to_keep: { rhino_objective: "Updated rich text" } }

        expect(response).to have_http_status(:ok)
        expect(keep.reload.rhino_objective.to_plain_text).to eq("Updated rich text")
      end
    end

    describe "POST dedupe_execute" do
      before { sign_in admin }

      let!(:keep) { create(:workshop, title: "Keep Workshop", published: true, objective: "Keep objective") }
      let!(:delete_rec) { create_workshop(title: "Dup Workshop", published: false, objective: "Delete objective") }

      it "merges and redirects with success notice" do
        expect {
          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }
        }.to change(Workshop, :count).by(-1)

        expect(response).to redirect_to(workshops_path)
        follow_redirect!
        expect(response.body).to include("merged successfully")
      end

      context "record fields" do
        it "updates keeper fields when keep params provided" do
          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id,
            workshop_to_keep: { title: "Merged Title", objective: "Merged objective" }
          }

          keep.reload
          expect(keep.title).to eq("Merged Title")
          expect(keep.objective).to eq("Merged objective")
        end

        it "preserves keeper fields when no keep params provided" do
          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          keep.reload
          expect(keep.title).to eq("Keep Workshop")
          expect(keep.objective).to eq("Keep objective")
        end
      end

      context "rich text (ActionText) fields" do
        it "updates keeper rich text when keep params provided" do
          keep.update!(rhino_objective: "Original rich text")

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id,
            workshop_to_keep: { rhino_objective: "Merged rich text" }
          }

          expect(keep.reload.rhino_objective.to_plain_text).to eq("Merged rich text")
        end

        it "preserves keeper rich text when no keep params provided" do
          keep.update!(rhino_objective: "Keep rich text")
          delete_rec.update!(rhino_objective: "Delete rich text")

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(keep.reload.rhino_objective.to_plain_text).to eq("Keep rich text")
        end

        it "destroys deleted record's rich text on merge" do
          delete_rec.update!(rhino_objective: "Will be lost")

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(ActionText::RichText.where(record_type: "Workshop", record_id: delete_rec.id)).not_to exist
        end
      end

      context "polymorphic join associations" do
        it "moves categorizable_items to the keeper" do
          category = create(:category, category_type: category_type)
          create(:categorizable_item, category: category, categorizable: delete_rec)

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(CategorizableItem.where(categorizable: keep).count).to eq(1)
          expect(CategorizableItem.where(categorizable: delete_rec).count).to eq(0)
        end

        it "moves sectorable_items to the keeper" do
          sector = create(:sector)
          create(:sectorable_item, sector: sector, sectorable: delete_rec)

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(SectorableItem.where(sectorable: keep).count).to eq(1)
          expect(SectorableItem.where(sectorable: delete_rec).count).to eq(0)
        end

        it "moves categorizable_items even when keeper already has a different category" do
          cat1 = create(:category, category_type: category_type)
          cat2 = create(:category, category_type: category_type)
          create(:categorizable_item, category: cat1, categorizable: keep)
          create(:categorizable_item, category: cat2, categorizable: delete_rec)

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(CategorizableItem.where(categorizable: keep).count).to eq(2)
          expect(CategorizableItem.where(categorizable: delete_rec).count).to eq(0)
        end
      end

      context "extra associations (direct FK)" do
        it "reassigns workshop_variations to the keeper" do
          variation = create(:workshop_variation, workshop: delete_rec)

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(variation.reload.workshop_id).to eq(keep.id)
        end

        it "reassigns workshop_resources to the keeper" do
          resource = create(:resource)
          wr = WorkshopResource.create!(workshop: delete_rec, resource: resource)

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(wr.reload.workshop_id).to eq(keep.id)
        end

        it "reassigns associated_resources to the keeper" do
          resource = create(:resource, workshop: delete_rec)

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(resource.reload.workshop_id).to eq(keep.id)
        end

        it "reassigns workshop_series_children to the keeper" do
          child_workshop = create(:workshop)
          membership = WorkshopSeriesMembership.create!(
            workshop_parent: delete_rec,
            workshop_child: child_workshop,
            position: 1
          )

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(membership.reload.workshop_parent_id).to eq(keep.id)
        end

        it "reassigns workshop_series_parents to the keeper" do
          parent_workshop = create(:workshop)
          membership = WorkshopSeriesMembership.create!(
            workshop_parent: parent_workshop,
            workshop_child: delete_rec,
            position: 1
          )

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(membership.reload.workshop_child_id).to eq(keep.id)
        end

        it "reassigns multiple workshop_resources to the keeper" do
          resource1 = create(:resource)
          resource2 = create(:resource)
          wr1 = WorkshopResource.create!(workshop: delete_rec, resource: resource1)
          wr2 = WorkshopResource.create!(workshop: delete_rec, resource: resource2)

          post dedupe_execute_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }

          expect(wr1.reload.workshop_id).to eq(keep.id)
          expect(wr2.reload.workshop_id).to eq(keep.id)
        end
      end
    end
  end
end
