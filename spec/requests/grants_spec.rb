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
