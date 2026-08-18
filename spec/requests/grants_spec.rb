require "rails_helper"

RSpec.describe "/grants", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:organization) { create(:organization) }

  let(:valid_attributes) do
    {
      name: "Healing Arts Grant",
      amount_dollars: "5000",
      funder_sgid: organization.to_signed_global_id.to_s,
      funds_allocation_deadline: "2026-12-31",
      eligibility_criteria: "Must be a facilitator",
      tasks: "Submit application"
    }
  end

  let(:invalid_attributes) do
    { name: "", amount_dollars: "1000", funder_sgid: "" }
  end

  describe "authorization" do
    it "redirects non-admins away from the index" do
      sign_in create(:user)
      get grants_url
      expect(response).to redirect_to(root_path)
    end
  end

  context "as an admin" do
    before { sign_in admin }

    describe "GET /index" do
      # The grant rows load inside the grants_results turbo frame, so row-level
      # assertions issue the frame request (Turbo-Frame header) the browser sends.
      let(:frame_headers) { { "Turbo-Frame" => "grants_results" } }

      it "renders a successful response" do
        create(:grant)
        get grants_url
        expect(response).to be_successful
      end

      it "shows a back link to the scholarship when opened from one" do
        scholarship = create(:scholarship)
        get grants_url(from_scholarship: scholarship.id)
        expect(response.body).to include(edit_scholarship_path(scholarship))
        expect(response.body).to include("Scholarship")
      end

      it "renders a per-row Edit link" do
        grant = create(:grant)
        get grants_url, headers: frame_headers
        expect(response.body).to include(edit_grant_path(grant))
      end

      it "filters by funds remaining" do
        available = create(:grant, name: "Has funds", amount_cents: 100_000)
        issued = create(:grant, name: "All issued", amount_cents: 30_000)
        create(:scholarship, grant: issued, amount_cents: 30_000)

        get grants_url(funds: "available"), headers: frame_headers
        expect(response.body).to include("Has funds")
        expect(response.body).not_to include("All issued")

        get grants_url(funds: "none"), headers: frame_headers
        expect(response.body).to include("All issued")
        expect(response.body).not_to include("Has funds")
      end

      it "filters by funder type" do
        org_grant = create(:grant, name: "Org grant", funder: create(:organization))
        person_grant = create(:grant, name: "Person grant", funder: create(:person))

        get grants_url(funder_type: "Organization"), headers: frame_headers
        expect(response.body).to include("Org grant")
        expect(response.body).not_to include("Person grant")

        get grants_url(funder_type: "Person"), headers: frame_headers
        expect(response.body).to include("Person grant")
        expect(response.body).not_to include("Org grant")
      end

      it "filters by legacy scholarship (planned giving)" do
        legacy = create(:grant, :planned_giving, name: "Legacy fund")
        ordinary = create(:grant, name: "Ordinary fund")

        get grants_url(planned_giving: "yes"), headers: frame_headers
        expect(response.body).to include("Legacy fund")
        expect(response.body).not_to include("Ordinary fund")

        get grants_url(planned_giving: "no"), headers: frame_headers
        expect(response.body).to include("Ordinary fund")
        expect(response.body).not_to include("Legacy fund")
      end

      it "filters by grant name" do
        create(:grant, name: "Healing Arts Fund")
        create(:grant, name: "Music Therapy Grant")

        get grants_url(name: "healing"), headers: frame_headers
        expect(response.body).to include("Healing Arts Fund")
        expect(response.body).not_to include("Music Therapy Grant")
      end

      it "filters by funder name across organizations and people" do
        org_grant = create(:grant, name: "Org-funded", funder: create(:organization, name: "Acme Foundation"))
        person_grant = create(:grant, name: "Person-funded", funder: create(:person, first_name: "Jane", last_name: "Funder"))
        create(:grant, name: "Other grant", funder: create(:organization, name: "Unrelated Inc"))

        get grants_url(funder_name: "acme"), headers: frame_headers
        expect(response.body).to include("Org-funded")
        expect(response.body).not_to include("Other grant")

        get grants_url(funder_name: "jane funder"), headers: frame_headers
        expect(response.body).to include("Person-funded")
        expect(response.body).not_to include("Other grant")
      end

      it "filters by a funder's legal first name" do
        create(:grant, name: "Legal-funded",
          funder: create(:person, first_name: "Bob", legal_first_name: "Robert", last_name: "Funder"))
        create(:grant, name: "Other grant", funder: create(:organization, name: "Unrelated Inc"))

        get grants_url(funder_name: "robert funder"), headers: frame_headers
        expect(response.body).to include("Legal-funded")
        expect(response.body).not_to include("Other grant")
      end

      it "filters by task completion" do
        all_done = create(:grant, name: "All done")
        create(:scholarship, grant: all_done, tasks_completed: true)
        outstanding = create(:grant, name: "Has outstanding")
        create(:scholarship, grant: outstanding, tasks_completed: false)

        get grants_url(tasks: "completed"), headers: frame_headers
        expect(response.body).to include("All done")
        expect(response.body).not_to include("Has outstanding")

        get grants_url(tasks: "outstanding"), headers: frame_headers
        expect(response.body).to include("Has outstanding")
        expect(response.body).not_to include("All done")
      end

      it "filters by sector and category tags for the taggings deep link" do
        sector = create(:sector, :published, name: "Homelessness")
        category = create(:category, :published, name: "Ages 10-13")
        tagged = create(:grant, name: "Tagged grant", sectors: [ sector ], categories: [ category ])
        create(:grant, name: "Untagged grant")

        get grants_url(sector_names_all: sector.name), headers: frame_headers
        expect(response.body).to include("Tagged grant")
        expect(response.body).not_to include("Untagged grant")

        get grants_url(category_names_all: category.name), headers: frame_headers
        expect(response.body).to include("Tagged grant")
        expect(response.body).not_to include("Untagged grant")
      end

      it "scopes to a single funder via funder_id and names it in the banner" do
        funder = create(:person, first_name: "Dana", last_name: "Funder")
        create(:grant, name: "Dana Fund", funder: funder)
        create(:grant, name: "Other Fund", funder: create(:organization, name: "Big Org"))

        # Banner renders on the full page (funder resolved in the non-frame branch).
        get grants_url(funder_id: funder.id, funder_type: "Person")
        expect(response.body).to include("Filtered to")
        expect(response.body).to include("Dana Funder")

        # Rows are scoped to that funder inside the results frame.
        get grants_url(funder_id: funder.id, funder_type: "Person"), headers: frame_headers
        expect(response.body).to include("Dana Fund")
        expect(response.body).not_to include("Other Fund")
      end
    end

    describe "GET /show" do
      it "renders a successful response" do
        get grant_url(create(:grant))
        expect(response).to be_successful
      end

      it "shows an uploaded primary photo" do
        grant = create(:grant)
        grant.create_primary_asset!.file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
          filename: "sample.png",
          content_type: "image/png"
        )

        get grant_url(grant)
        expect(response).to be_successful
        expect(response.body).to include("sample")
      end

      it "shows the grant's sector and category tags" do
        sector = create(:sector, :published, name: "Domestic Violence")
        category = create(:category, :published, name: "Ages 6-9")
        grant = create(:grant, sectors: [ sector ], categories: [ category ])

        get grant_url(grant)
        expect(response.body).to include("Domestic Violence")
        expect(response.body).to include("Ages 6-9")
      end
    end

    describe "GET /new" do
      it "renders a successful response" do
        get new_grant_url
        expect(response).to be_successful
      end
    end

    describe "GET /edit" do
      it "renders a successful response" do
        get edit_grant_url(create(:grant))
        expect(response).to be_successful
      end
    end

    describe "POST /create" do
      context "with valid parameters" do
        it "creates a new Grant attributed to the current user" do
          expect {
            post grants_url, params: { grant: valid_attributes }
          }.to change(Grant, :count).by(1)

          grant = Grant.last
          expect(grant.funder).to eq(organization)
          expect(grant.amount_cents).to eq(500_000)
          expect(grant.created_by).to eq(admin)
        end

        it "redirects to the created grant" do
          post grants_url, params: { grant: valid_attributes }
          expect(response).to redirect_to(grant_url(Grant.last))
        end

        it "attaches an uploaded primary photo" do
          expect {
            post grants_url, params: {
              grant: valid_attributes.merge(
                primary_asset_attributes: {
                  file: fixture_file_upload("spec/fixtures/files/sample.png", "image/png")
                }
              )
            }
          }.to change(Grant, :count).by(1)

          expect(Grant.last.primary_asset.file).to be_attached
        end

        it "flags the grant as planned giving when checked" do
          post grants_url, params: { grant: valid_attributes.merge(planned_giving: "1") }

          expect(Grant.last).to be_planned_giving
        end

        it "flags the grant as in memoriam when checked" do
          post grants_url, params: { grant: valid_attributes.merge(planned_giving: "1", in_memoriam: "1") }

          expect(Grant.last).to be_in_memoriam
        end

        it "attaches the selected sectors and categories" do
          sector = create(:sector, :published)
          category = create(:category, :published)

          post grants_url, params: {
            grant: valid_attributes.merge(sector_ids: [ sector.id ], category_ids: [ category.id ])
          }

          grant = Grant.last
          expect(grant.sectors).to contain_exactly(sector)
          expect(grant.categories).to contain_exactly(category)
        end
      end

      context "with invalid parameters" do
        it "does not create a new Grant" do
          expect {
            post grants_url, params: { grant: invalid_attributes }
          }.not_to change(Grant, :count)
        end

        it "renders a 422 response" do
          post grants_url, params: { grant: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "surfaces the missing-funder error on the funder field, not just the summary" do
          post grants_url, params: { grant: invalid_attributes }

          # simple_form wraps the funder_sgid input with the error class when the
          # attribute has an error, so the message renders inline on the field.
          expect(response.body).to include("Funder must be selected")
          expect(response.body).to include("must be selected")
        end
      end
    end

    describe "PATCH /update" do
      it "updates the requested grant" do
        grant = create(:grant)
        patch grant_url(grant), params: { grant: valid_attributes.merge(name: "Renamed Grant") }
        expect(grant.reload.name).to eq("Renamed Grant")
        expect(response).to redirect_to(grant_url(grant))
      end

      it "renders a 422 response with invalid parameters" do
        grant = create(:grant)
        patch grant_url(grant), params: { grant: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "replaces the grant's sectors and categories" do
        old_sector = create(:sector, :published)
        grant = create(:grant, sectors: [ old_sector ])
        new_sector = create(:sector, :published)
        category = create(:category, :published)

        patch grant_url(grant), params: {
          grant: valid_attributes.merge(sector_ids: [ new_sector.id ], category_ids: [ category.id ])
        }

        expect(grant.reload.sectors).to contain_exactly(new_sector)
        expect(grant.categories).to contain_exactly(category)
      end
    end

    describe "DELETE /destroy" do
      it "destroys the requested grant" do
        grant = create(:grant)
        expect {
          delete grant_url(grant)
        }.to change(Grant, :count).by(-1)
        expect(response).to redirect_to(grants_url)
      end

      it "refuses to destroy a grant that has associated scholarships" do
        grant = create(:grant)
        create(:scholarship, grant:, amount_cents: 1_000)

        expect {
          delete grant_url(grant)
        }.not_to change(Grant, :count)
        expect(response).to redirect_to(grant_url(grant))
        expect(flash[:alert]).to include("associated scholarships")
      end
    end
  end
end
