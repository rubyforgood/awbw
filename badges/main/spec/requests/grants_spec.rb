require "rails_helper"

RSpec.describe "/grants", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:organization) { create(:organization) }

  let(:valid_attributes) do
    {
      name: "Healing Arts Grant",
      amount_dollars: "5000",
      donor_sgid: organization.to_signed_global_id.to_s,
      application_deadline: "2026-12-31",
      eligibility_criteria: "Must be a facilitator",
      tasks: "Submit application"
    }
  end

  let(:invalid_attributes) do
    { name: "", amount_dollars: "1000", donor_sgid: "" }
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

      it "filters by donor type" do
        org_grant = create(:grant, name: "Org grant", donor: create(:organization))
        person_grant = create(:grant, name: "Person grant", donor: create(:person))

        get grants_url(donor_type: "Organization"), headers: frame_headers
        expect(response.body).to include("Org grant")
        expect(response.body).not_to include("Person grant")

        get grants_url(donor_type: "Person"), headers: frame_headers
        expect(response.body).to include("Person grant")
        expect(response.body).not_to include("Org grant")
      end

      it "filters by grant name" do
        create(:grant, name: "Healing Arts Fund")
        create(:grant, name: "Music Therapy Grant")

        get grants_url(name: "healing"), headers: frame_headers
        expect(response.body).to include("Healing Arts Fund")
        expect(response.body).not_to include("Music Therapy Grant")
      end

      it "filters by donor name across organizations and people" do
        org_grant = create(:grant, name: "Org-funded", donor: create(:organization, name: "Acme Foundation"))
        person_grant = create(:grant, name: "Person-funded", donor: create(:person, first_name: "Jane", last_name: "Donor"))
        create(:grant, name: "Other grant", donor: create(:organization, name: "Unrelated Inc"))

        get grants_url(donor_name: "acme"), headers: frame_headers
        expect(response.body).to include("Org-funded")
        expect(response.body).not_to include("Other grant")

        get grants_url(donor_name: "jane donor"), headers: frame_headers
        expect(response.body).to include("Person-funded")
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
    end

    describe "GET /show" do
      it "renders a successful response" do
        get grant_url(create(:grant))
        expect(response).to be_successful
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
          expect(grant.donor).to eq(organization)
          expect(grant.amount_cents).to eq(500_000)
          expect(grant.created_by).to eq(admin)
        end

        it "redirects to the created grant" do
          post grants_url, params: { grant: valid_attributes }
          expect(response).to redirect_to(grant_url(Grant.last))
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
