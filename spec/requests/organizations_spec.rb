require "rails_helper"

RSpec.describe "/organizations", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let!(:location) { create(:location) }
  let!(:organization_status) { create(:organization_status, name: "Active") }

  let(:valid_attributes) do
    {
      name: "Healing Through Art",
      description: "A community program supporting trauma-informed workshops.",
      start_date: Date.today - 6.months,
      end_date: Date.today + 6.months,
      organization_status_id: organization_status.id,
      notes: "Runs bi-weekly at community centers."
    }
  end

  let(:invalid_attributes) do
    {
      name: "", # required field missing
      description: nil,
      organization_status_id: nil,
      windows_type_id: nil
    }
  end

  before do
    sign_in admin
  end

  describe "GET /index" do
    it "renders a successful response" do
      Organization.create!(valid_attributes)
      get organizations_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      organization = Organization.create!(valid_attributes)
      get organization_url(organization)
      expect(response).to be_successful
    end

    it "renders successfully with workshop logs" do
      organization = Organization.create!(valid_attributes)
      workshop_log = create(:workshop_log, organization: organization, created_by: admin)
      get organization_url(organization)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_organization_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      organization = Organization.create!(valid_attributes)
      get edit_organization_url(organization)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Organization" do
        expect {
          post organizations_url, params: { organization: valid_attributes }
        }.to change(Organization, :count).by(1)
      end

      it "redirects to the created organization" do
        post organizations_url, params: { organization: valid_attributes }
        expect(response).to redirect_to(organization_url(Organization.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Organization" do
        expect {
          post organizations_url, params: { organization: invalid_attributes }
        }.not_to change(Organization, :count)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post organizations_url, params: { organization: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        {
          name: "Updated Healing Organization",
          description: "Updated description for testing."
        }
      end

      it "updates the requested organization" do
        organization = Organization.create!(valid_attributes)
        patch organization_url(organization), params: { organization: new_attributes }
        organization.reload
        expect(organization.name).to eq("Updated Healing Organization")
        expect(organization.description).to eq("Updated description for testing.")
      end

      it "redirects to the organization profile" do
        organization = Organization.create!(valid_attributes)
        patch organization_url(organization), params: { organization: new_attributes }
        expect(response).to redirect_to(organization_url(organization))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        organization = Organization.create!(valid_attributes)
        patch organization_url(organization), params: { organization: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "sector saving" do
    let!(:sector) { create(:sector, :published) }
    let(:organization) { Organization.create!(valid_attributes) }

    it "saves sectors via nested attributes on create" do
      post organizations_url, params: {
        organization: valid_attributes.merge(
          category_ids: [ "" ],
          sectorable_items_attributes: {
            "0" => { sector_id: sector.id, _destroy: "false" }
          }
        )
      }

      expect(Organization.last.sectors).to include(sector)
    end

    it "saves sectors via nested attributes on update" do
      patch organization_url(organization), params: {
        organization: {
          name: organization.name,
          category_ids: [ "" ],
          sectorable_items_attributes: {
            "0" => { sector_id: sector.id, _destroy: "false" }
          }
        }
      }

      organization.reload
      expect(organization.sectors).to include(sector)
    end

    it "preserves existing sectors when updating other fields" do
      organization.sectorable_items.create!(sector: sector)
      expect(organization.sectors).to include(sector)

      patch organization_url(organization), params: {
        organization: {
          name: "Updated Name",
          category_ids: [ "" ]
        }
      }

      organization.reload
      expect(organization.sectors).to include(sector)
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested organization" do
      organization = Organization.create!(valid_attributes)
      expect {
        delete organization_url(organization)
      }.to change(Organization, :count).by(-1)
    end

    it "redirects to the organizations list" do
      organization = Organization.create!(valid_attributes)
      delete organization_url(organization)
      expect(response).to redirect_to(organizations_url)
    end

    context "when the organization has affiliations" do
      it "does not destroy and redirects with an alert" do
        organization = Organization.create!(valid_attributes)
        create(:affiliation, organization: organization)

        expect {
          delete organization_url(organization)
        }.not_to change(Organization, :count)

        expect(response).to redirect_to(organization_url(organization))
        expect(flash[:alert]).to include("Unable to delete this organization")
      end

      it "renders the alert on the page after following the redirect" do
        organization = Organization.create!(valid_attributes)
        create(:affiliation, organization: organization)

        delete organization_url(organization)
        follow_redirect!

        expect(response.body).to include("Unable to delete this organization")
      end
    end

    context "when the organization has associated workshop logs" do
      it "does not destroy and redirects with an alert" do
        organization = Organization.create!(valid_attributes)
        create(:workshop_log, organization: organization, created_by: admin)

        expect {
          delete organization_url(organization)
        }.not_to change(Organization, :count)

        expect(response).to redirect_to(organization_url(organization))
        expect(flash[:alert]).to include("associated records that cannot be removed")
      end

      it "renders the alert on the page after following the redirect" do
        organization = Organization.create!(valid_attributes)
        create(:workshop_log, organization: organization, created_by: admin)

        delete organization_url(organization)
        follow_redirect!

        expect(response.body).to include("associated records that cannot be removed")
      end
    end
  end

  describe "POST /create with duplicate check" do
    let!(:existing_org) { create(:organization, name: "Healing Through Art") }

    context "when exact duplicate exists" do
      it "blocks creation and shows duplicate warning" do
        expect {
          post organizations_url, params: { organization: valid_attributes.merge(name: "Healing Through Art") }
        }.not_to change(Organization, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when similar duplicate exists" do
      it "blocks creation and shows duplicate warning" do
        expect {
          post organizations_url, params: { organization: valid_attributes.merge(name: "Healing Through Art Center") }
        }.not_to change(Organization, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when no duplicate exists" do
      it "creates the organization normally" do
        expect {
          post organizations_url, params: { organization: valid_attributes.merge(name: "Completely Different Org") }
        }.to change(Organization, :count).by(1)

        expect(response).to redirect_to(organization_url(Organization.last))
      end
    end

    context "with skip_duplicate_check param" do
      it "creates organization without duplicate check" do
        expect {
          post organizations_url, params: {
            organization: valid_attributes.merge(name: "Healing Through Art Center"),
            skip_duplicate_check: "1"
          }
        }.to change(Organization, :count).by(1)

        expect(response).to redirect_to(organization_url(Organization.last))
      end
    end
  end

  describe "POST /create turbo stream duplicate check" do
    context "when similar duplicate exists" do
      let!(:existing_org) { create(:organization, name: "Healing Through Art") }

      it "returns turbo stream with skip checkbox" do
        post organizations_url, params: {
          organization: valid_attributes.merge(name: "Healing Through Art Center")
        }, as: :turbo_stream

        expect(response.media_type).to eq(Mime[:turbo_stream])
        expect(response.body).to include("skip_duplicate_check")
        expect(response.body).to include("similar match")
      end
    end

    context "when exact duplicate exists" do
      let!(:existing_org) { create(:organization, name: "Healing Through Art") }

      it "returns turbo stream without skip checkbox" do
        post organizations_url, params: {
          organization: valid_attributes.merge(name: "Healing Through Art")
        }, as: :turbo_stream

        expect(response.media_type).to eq(Mime[:turbo_stream])
        expect(response.body).not_to include("skip_duplicate_check")
        expect(response.body).to include("exact match")
      end
    end
  end
end
