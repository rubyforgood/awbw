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
          expect(response).to redirect_to(new_user_session_path)
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

    describe "POST dedupe_perform" do
      let!(:keep) { create(:category, name: "Keeper", category_type: category_type, published: true) }
      let!(:delete_rec) { create(:category, name: "Duplicate", category_type: category_type, published: false) }
      let!(:workshop) { create(:workshop) }
      let!(:tagging) { create(:categorizable_item, category: delete_rec, categorizable: workshop) }

      context "as an admin" do
        before { sign_in admin }

        it "merges and redirects with success notice" do
          post dedupe_perform_categories_path, params: {
            category_to_delete_id: delete_rec.id,
            category_to_keep_id: keep.id
          }

          expect(response).to redirect_to(categories_path)
          follow_redirect!
          expect(response.body).to include("merged successfully")
        end

        it "deletes the duplicate record" do
          expect {
            post dedupe_perform_categories_path, params: {
              category_to_delete_id: delete_rec.id,
              category_to_keep_id: keep.id
            }
          }.to change(Category, :count).by(-1)

          expect(Category.exists?(keep.id)).to be true
          expect(Category.exists?(delete_rec.id)).to be false
        end

        it "moves taggings to the keeper" do
          post dedupe_perform_categories_path, params: {
            category_to_delete_id: delete_rec.id,
            category_to_keep_id: keep.id
          }

          expect(CategorizableItem.where(category_id: keep.id).count).to eq(1)
          expect(CategorizableItem.where(category_id: delete_rec.id).count).to eq(0)
        end

        it "updates the keeper before merging when keep params provided" do
          post dedupe_perform_categories_path, params: {
            category_to_delete_id: delete_rec.id,
            category_to_keep_id: keep.id,
            category_to_keep: { name: "Better Name" }
          }

          expect(keep.reload.name).to eq("Better Name")
        end

        it "redirects to dedupe_index on error" do
          post dedupe_perform_categories_path, params: {
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
            post dedupe_perform_categories_path, params: {
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

    describe "POST dedupe_perform" do
      before { sign_in admin }

      let!(:keep) { create(:sector, name: "Keep Sector", published: true) }
      let!(:delete_rec) { create(:sector, name: "Dup Sector", published: false) }
      let!(:workshop) { create(:workshop) }
      let!(:tagging) { create(:sectorable_item, sector: delete_rec, sectorable: workshop) }

      it "merges and redirects with success notice" do
        expect {
          post dedupe_perform_sectors_path, params: {
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
  # ORGANIZATIONS — FK-based model with a custom candidate finder
  # ============================================================

  describe "Organizations" do
    before { sign_in admin }

    describe "GET dedupe_index" do
      it "renders and surfaces candidate groups from the duplicate finder" do
        create(:organization, name: "Hope Center")
        create(:organization, name: "hope center")

        get dedupe_index_organizations_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Same name")
      end
    end

    describe "GET dedupe_preview" do
      let!(:keep) { create(:organization, name: "Keep Org") }
      let!(:delete_rec) { create(:organization, name: "Delete Org") }
      before { create(:affiliation, organization: delete_rec) }

      it "renders the preview with a reassignment summary and curated fields" do
        get dedupe_preview_organizations_path(
          organization_to_keep_id: keep.id,
          organization_to_delete_id: delete_rec.id
        )

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Keep Org", "Delete Org")
        expect(response.body).to include("Records that will move", "Affiliations")
        expect(response.body).to include("Website url")
        expect(response.body).not_to include("Profile show age ranges")
      end
    end

    describe "POST dedupe_perform" do
      let!(:keep) { create(:organization, name: "Keeper Org") }
      let!(:delete_rec) { create(:organization, name: "Duplicate Org") }
      let!(:report) { create(:report, organization: delete_rec) }

      it "merges, reassigns FK associations, and deletes the duplicate" do
        expect {
          post dedupe_perform_organizations_path, params: {
            organization_to_delete_id: delete_rec.id,
            organization_to_keep_id: keep.id
          }
        }.to change(Organization, :count).by(-1)

        expect(response).to redirect_to(organizations_path)
        expect(Organization.exists?(delete_rec.id)).to be false
        expect(report.reload.organization_id).to eq(keep.id)
      end

      it "applies keep-field edits before merging" do
        post dedupe_perform_organizations_path, params: {
          organization_to_delete_id: delete_rec.id,
          organization_to_keep_id: keep.id,
          organization_to_keep: { name: "Canonical Org" }
        }

        expect(keep.reload.name).to eq("Canonical Org")
      end

      it "blocks the merge when an association would be orphaned" do
        create(:other_response, promotable: delete_rec)

        get dedupe_preview_organizations_path(
          organization_to_delete_id: delete_rec.id,
          organization_to_keep_id: keep.id
        )
        expect(response.body).to include("Merge blocked")

        expect {
          post dedupe_perform_organizations_path, params: {
            organization_to_delete_id: delete_rec.id,
            organization_to_keep_id: keep.id
          }
        }.not_to change(Organization, :count)
        expect(response).to redirect_to(dedupe_index_organizations_path)
        expect(Organization.exists?(delete_rec.id)).to be true
      end

      it "combines both organizations' FileMaker codes onto the keeper" do
        keep.update!(filemaker_code: "FM-100")
        delete_rec.update!(filemaker_code: "FM-273")

        post dedupe_perform_organizations_path, params: {
          organization_to_delete_id: delete_rec.id,
          organization_to_keep_id: keep.id
        }

        expect(keep.reload.filemaker_code).to eq("FM-100, FM-273")
      end
    end
  end

  # ============================================================
  # PEOPLE — FK-based model with a candidate finder and a merge guard
  # ============================================================

  describe "People" do
    before { sign_in admin }

    describe "GET dedupe_index" do
      it "renders and surfaces candidate groups from the duplicate finder" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "jane@example.com", user: nil)
        create(:person, first_name: "Jane", last_name: "Doe", email: "jane@work.com", user: nil)

        get dedupe_index_people_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Same name")
      end
    end

    describe "GET dedupe_preview" do
      let!(:keep) { create(:person, first_name: "Keep", last_name: "Person", user: nil) }
      let!(:delete_rec) { create(:person, first_name: "Delete", last_name: "Person", user: nil) }
      before { create(:affiliation, person: delete_rec) }

      it "renders the preview with a reassignment summary and curated fields" do
        get dedupe_preview_people_path(
          person_to_keep_id: keep.id,
          person_to_delete_id: delete_rec.id
        )

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Keep", "Delete")
        expect(response.body).to include("Records that will move", "Affiliations")
        expect(response.body).to include("Date of birth")
        expect(response.body).not_to include("Profile show age ranges")
      end
    end

    describe "POST dedupe_perform" do
      let!(:keep) { create(:person, first_name: "Keeper", last_name: "Person", user: nil) }
      let!(:delete_rec) { create(:person, first_name: "Duplicate", last_name: "Person", user: nil) }
      let!(:affiliation) { create(:affiliation, person: delete_rec) }

      it "merges, reassigns FK associations, and deletes the duplicate" do
        expect {
          post dedupe_perform_people_path, params: {
            person_to_delete_id: delete_rec.id,
            person_to_keep_id: keep.id
          }
        }.to change(Person, :count).by(-1)

        expect(response).to redirect_to(people_path)
        expect(Person.exists?(delete_rec.id)).to be false
        expect(affiliation.reload.person_id).to eq(keep.id)
      end

      it "merges exact duplicates (same name and email) despite the uniqueness validation" do
        keep.update!(first_name: "Sam", last_name: "Twin", email: "twin@example.com")
        dupe = build(:person, first_name: "Sam", last_name: "Twin", email: "twin@example.com", user: nil)
        dupe.save!(validate: false)

        expect {
          post dedupe_perform_people_path, params: {
            person_to_delete_id: dupe.id,
            person_to_keep_id: keep.id,
            person_to_keep: { first_name: "Sam", last_name: "Twin", email: "twin@example.com", notes: "Canonical record" }
          }
        }.to change(Person, :count).by(-1)

        expect(Person.exists?(dupe.id)).to be false
        expect(keep.reload.notes).to eq("Canonical record")
      end
    end

    describe "when both people have a linked login" do
      let!(:keep) { create(:person, first_name: "Login", last_name: "One") }
      let!(:delete_rec) { create(:person, first_name: "Login", last_name: "Two") }

      it "surfaces a non-blocking heads-up on the preview and keeps the merge enabled" do
        get dedupe_preview_people_path(
          person_to_keep_id: keep.id,
          person_to_delete_id: delete_rec.id
        )

        expect(response.body).to include("Both people have a login")
        expect(response.body).not_to include("Merge blocked")
      end

      it "merges and points both logins at the kept person" do
        keep_user = keep.user
        delete_user = delete_rec.user

        expect {
          post dedupe_perform_people_path, params: {
            person_to_delete_id: delete_rec.id,
            person_to_keep_id: keep.id
          }
        }.to change(Person, :count).by(-1)

        expect(Person.exists?(delete_rec.id)).to be false
        expect(keep_user.reload.person_id).to eq(keep.id)
        expect(delete_user.reload.person_id).to eq(keep.id)
      end
    end
  end

  # ============================================================
  # WORKSHOPS — dedupe wired through WorkshopsController on the
  # config-driven Dedupable pattern, matched by title.
  # ============================================================

  describe "Workshops" do
    describe "GET dedupe_index" do
      it "surfaces title-matched candidate groups for an admin" do
        sign_in admin
        create(:workshop, title: "Paper Bag Puppets")
        create(:workshop, title: "paper bag puppets")

        get dedupe_index_workshops_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Same title")
      end

      it "denies access to a regular user" do
        sign_in regular_user
        get dedupe_index_workshops_path
        expect(response).not_to have_http_status(:ok)
      end
    end

    describe "GET dedupe_preview" do
      let!(:keep_author) { create(:person, first_name: "Ada", last_name: "Keeper") }
      let!(:delete_author) { create(:person, first_name: "Ben", last_name: "Duplicate") }
      let!(:keep) { create(:workshop, title: "Keep Workshop", author: keep_author) }
      let!(:delete_rec) { create(:workshop, title: "Delete Workshop", author: delete_author) }
      before do
        sign_in admin
        create(:workshop_log, workshop: delete_rec)
      end

      it "renders the preview with a reassignment summary" do
        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: delete_rec.id
        )

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Keep Workshop", "Delete Workshop")
      end

      it "links each record's title to its edit page" do
        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: delete_rec.id
        )

        expect(response.body).to include("href=\"#{edit_workshop_path(keep)}\"")
        expect(response.body).to include("href=\"#{edit_workshop_path(delete_rec)}\"")
      end

      it "surfaces each workshop's author with a searchable picker on the kept record" do
        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: delete_rec.id
        )

        expect(response.body).to include("Author")
        expect(response.body).to include("Ada Keeper", "Ben Duplicate")
        expect(response.body).to include("[workshop_to_keep][author_id]")
        expect(response.body).to include('data-controller="remote-select"')
        expect(response.body).to include('data-remote-select-model-value="person"')
      end

      it "notes that Full name is the legacy author and Author should be a person" do
        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: delete_rec.id
        )

        expect(response.body).to include("Legacy (not referenced)")
        expect(response.body).to include("Credited author")
      end

      it "marks the legacy Full name field as deprecated" do
        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: delete_rec.id
        )

        expect(response.body).to include("Deprecated")
      end

      it "lists belongs_to references not shown as fields in a read-only Linked records section" do
        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: delete_rec.id
        )

        expect(response.body).to include("Linked records")
        expect(response.body).to include("Created by")
      end

      it "shows a thumbnail on the deleted workshop as moving to the keeper" do
        blob = ActiveStorage::Blob.create_before_direct_upload!(
          filename: "thumb.png", byte_size: 1, checksum: "x", content_type: "image/png"
        )
        ActiveStorage::Attachment.create!(name: "thumbnail", record: delete_rec, blob: blob)

        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: delete_rec.id
        )

        expect(response.body).to include("Attached images")
        expect(response.body).to include("Moves to keeper")
      end

      it "renders each workshop's photos and shows the deleted record's moving to the keeper" do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("img"), filename: "del.png", content_type: "image/png"
        )
        ActiveStorage::Attachment.create!(name: "thumbnail", record: delete_rec, blob: blob)

        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: delete_rec.id
        )

        expect(response.body).to include("Photos")
        expect(response.body).to include("active_storage/blobs")
        expect(response.body).to include("Move to the kept workshop")
      end

      it "still renders the author picker when neither workshop has a person author" do
        keep.update!(author: nil)
        delete_rec.update!(author: nil)

        get dedupe_preview_workshops_path(
          workshop_to_keep_id: keep.id,
          workshop_to_delete_id: delete_rec.id
        )

        expect(response.body).to include("[workshop_to_keep][author_id]")
        expect(response.body).to include('data-controller="remote-select"')
      end
    end

    describe "POST dedupe_perform" do
      let!(:keep) { create(:workshop, title: "Keeper Workshop") }
      let!(:delete_rec) { create(:workshop, title: "Duplicate Workshop") }
      let!(:log) { create(:workshop_log, workshop: delete_rec) }

      it "merges, reassigns FK associations, and deletes the duplicate" do
        sign_in admin

        expect {
          post dedupe_perform_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }
        }.to change(Workshop, :count).by(-1)

        expect(response).to redirect_to(workshops_path)
        expect(Workshop.exists?(delete_rec.id)).to be false
        expect(log.reload.workshop_id).to eq(keep.id)
      end

      it "applies keep-field edits before merging" do
        sign_in admin

        post dedupe_perform_workshops_path, params: {
          workshop_to_delete_id: delete_rec.id,
          workshop_to_keep_id: keep.id,
          workshop_to_keep: { title: "Canonical Workshop" }
        }

        expect(keep.reload.title).to eq("Canonical Workshop")
      end

      it "denies access to a regular user and does not merge" do
        sign_in regular_user

        expect {
          post dedupe_perform_workshops_path, params: {
            workshop_to_delete_id: delete_rec.id,
            workshop_to_keep_id: keep.id
          }
        }.not_to change(Workshop, :count)
      end
    end
  end

  # ============================================================
  # EVENT REGISTRATIONS — one person registered for the same event
  # under two different Person records. Merging combines the
  # registrations only; the people stay separate.
  # ============================================================

  describe "Event registrations" do
    before { sign_in admin }

    let(:event) { create(:event) }

    def registration_for(person_attrs)
      create(:event_registration, event: event, registrant: create(:person, { user: nil }.merge(person_attrs)))
    end

    describe "GET dedupe_index" do
      it "surfaces same-event candidate groups from the duplicate finder" do
        registration_for(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
        registration_for(first_name: "Jane", last_name: "Doe", email: "jane@work.com")

        get dedupe_index_event_registrations_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Same registrant name")
      end

      it "denies access to a regular user" do
        sign_in regular_user
        get dedupe_index_event_registrations_path
        expect(response).not_to have_http_status(:ok)
      end

      it "scopes suggestions to one event and returns the eyebrow there when opened from it" do
        registration_for(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
        registration_for(first_name: "Jane", last_name: "Doe", email: "jane@work.com")
        other_event = create(:event)
        create(:event_registration, event: other_event, registrant: create(:person, first_name: "Zed", last_name: "Zed", email: "z1@example.com", user: nil))
        create(:event_registration, event: other_event, registrant: create(:person, first_name: "Zed", last_name: "Zed", email: "z2@example.com", user: nil))

        get dedupe_index_event_registrations_path(event_id: event.id)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Jane Doe")
        expect(response.body).not_to include("Zed Zed")
        expect(response.body).to include(registrants_event_path(event))
        expect(response.body).to include("Showing possible duplicate registrations for")
      end
    end

    describe "GET dedupe_preview" do
      let!(:keep) { registration_for(first_name: "Keep", last_name: "Person", email: "keep@example.com") }
      let!(:delete_rec) { registration_for(first_name: "Kepe", last_name: "Persson", email: "keep@example.com") }
      before { create(:event_attendance_time_entry, event_registration: delete_rec) }

      it "renders the preview with a reassignment summary" do
        get dedupe_preview_event_registrations_path(
          event_registration_to_keep_id: keep.id,
          event_registration_to_delete_id: delete_rec.id
        )

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Records that will move")
      end

      it "notes that a merge across different registrants keeps the people separate" do
        get dedupe_preview_event_registrations_path(
          event_registration_to_keep_id: keep.id,
          event_registration_to_delete_id: delete_rec.id
        )

        expect(response.body).to include("different registrants")
        expect(response.body).not_to include("Merge blocked")
      end
    end

    describe "POST dedupe_perform" do
      let!(:keep) { registration_for(first_name: "Keeper", last_name: "Person", email: "dupe@example.com") }
      let!(:delete_rec) { registration_for(first_name: "Keepr", last_name: "Persn", email: "dupe@example.com") }
      let!(:time_entry) { create(:event_attendance_time_entry, event_registration: delete_rec) }

      it "merges, reassigns child records, and deletes the duplicate" do
        expect {
          post dedupe_perform_event_registrations_path, params: {
            event_registration_to_delete_id: delete_rec.id,
            event_registration_to_keep_id: keep.id
          }
        }.to change(EventRegistration, :count).by(-1)

        expect(response).to redirect_to(event_registrations_path)
        expect(EventRegistration.exists?(delete_rec.id)).to be false
        expect(time_entry.reload.event_registration_id).to eq(keep.id)
      end

      it "applies keep-field edits before merging" do
        post dedupe_perform_event_registrations_path, params: {
          event_registration_to_delete_id: delete_rec.id,
          event_registration_to_keep_id: keep.id,
          event_registration_to_keep: { fee_note: "Canonical registration" }
        }

        expect(keep.reload.fee_note).to eq("Canonical registration")
      end

      it "moves the deleted registration's scholarship onto the keeper and re-credits it to the kept registrant" do
        scholarship = create(:scholarship, recipient: delete_rec.registrant, amount_cents: 1_000)
        create(:allocation, source: scholarship, allocatable: delete_rec, amount: 1_000)

        post dedupe_perform_event_registrations_path, params: {
          event_registration_to_delete_id: delete_rec.id,
          event_registration_to_keep_id: keep.id
        }

        expect(keep.reload.scholarships).to include(scholarship)
        expect(scholarship.reload.recipient).to eq(keep.registrant)
      end

      it "moves the deleted registration's CE registration onto the keeper" do
        ce = create(:continuing_education_registration, event_registration: delete_rec)

        post dedupe_perform_event_registrations_path, params: {
          event_registration_to_delete_id: delete_rec.id,
          event_registration_to_keep_id: keep.id
        }

        expect(ce.reload.event_registration_id).to eq(keep.id)
      end

      it "denies access to a regular user and does not merge" do
        sign_in regular_user

        expect {
          post dedupe_perform_event_registrations_path, params: {
            event_registration_to_delete_id: delete_rec.id,
            event_registration_to_keep_id: keep.id
          }
        }.not_to change(EventRegistration, :count)
      end
    end
  end
end
