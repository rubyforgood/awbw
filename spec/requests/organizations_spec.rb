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

    it "shows single-letter program status badges per organization" do
      create(:organization, name: "Brand New Org", organization_status: organization_status)

      ongoing_org = create(:organization, name: "Ongoing Org", organization_status: organization_status)
      create(:affiliation, organization: ongoing_org, person: create(:person), title: "Facilitator")

      reinstate_org = create(:organization, name: "Reinstate Org", organization_status: organization_status)
      create(:affiliation, organization: reinstate_org, person: create(:person), title: "Facilitator", end_date: 1.year.ago.to_date)

      get organizations_url, headers: { "Turbo-Frame" => "organization_results" }

      expect(response).to be_successful
      page = Capybara.string(response.body)
      expect(page).to have_css("span[title='New']", text: "N")
      expect(page).to have_css("span[title='Ongoing']", text: "O")
      expect(page).to have_css("span[title='Reinstated']", text: "R")
    end

    it "renders the results frame with deduped age groups from affiliated people" do
      organization = Organization.create!(valid_attributes)
      age_type = create(:category_type, name: "AgeRange", published: true)
      teen = create(:category, :published, category_type: age_type, name: "13-17")
      person = create(:person)
      create(:affiliation, organization: organization, person: person)
      person.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])

      get organizations_url, headers: { "Turbo-Frame" => "organization_results" }

      expect(response).to be_successful
      expect(response.body).to include("13-17")
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

    it "hides the Monthly reports row when there are no monthly reports" do
      organization = Organization.create!(valid_attributes)
      get organization_url(organization)
      expect(response.body).not_to include("Monthly reports")
    end

    it "shows the Monthly reports row when monthly reports exist" do
      organization = Organization.create!(valid_attributes)
      create(:monthly_report, organization: organization)
      get organization_url(organization)
      expect(response.body).to include("Monthly reports")
    end
  end

  describe "sector displays" do
    let!(:organization_with_sectors) do
      affiliated_sector_1 = create(:sector, name: "Affiliated Sector 1")
      affiliated_sector_2 = create(:sector, name: "Affiliated Sector 2")
      person_1 = create(:person)
      person_2 = create(:person)
      create(:sectorable_item, sector: affiliated_sector_1, sectorable: person_1)
      create(:sectorable_item, sector: affiliated_sector_2, sectorable: person_2)

      org = create(:organization, organization_status: organization_status)
      create(:sectorable_item, sector: create(:sector, name: "Direct Sector 1"), sectorable: org)
      create(:sectorable_item, sector: create(:sector, name: "Direct Sector 2"), sectorable: org)
      create(:affiliation, organization: org, person: person_1, position: :default)
      create(:affiliation, organization: org, person: person_2, position: :default)
      org
    end

    it "truncates sectors to the first 3 with a 'more' indicator on the show page" do
      get organization_url(organization_with_sectors)

      page = Capybara.string(response.body)
      all_sector_names = organization_with_sectors.all_sectors.map(&:name).sort
      expect(all_sector_names.length).to be > 3
      all_sector_names.first(3).each { |name| expect(page).to have_content(name) }
      expect(page).not_to have_content(all_sector_names[3])
      expect(page).to have_content(/\+?[0-9]+ more|\.\.\./i)
    end

    it "lists all sectors with per-sector people counts on the populations served page" do
      get populations_served_organization_url(organization_with_sectors)

      page = Capybara.string(response.body)
      expect(page).to have_content("Sector Distribution")
      expect(page).to have_content(organization_with_sectors.name)

      organization_with_sectors.all_sectors.map(&:name).each do |name|
        expect(page).to have_content(name)
      end

      people = organization_with_sectors.users.includes(person: :sectors).map(&:person).compact
      expected_counts = Hash.new(0)
      people.each do |person|
        primary_sector = person.sectors.first
        expected_counts[primary_sector.name] += 1 if primary_sector
      end
      expected_counts.each do |_sector_name, count|
        expect(page).to have_content("#{count} #{count == 1 ? 'person' : 'people'}")
      end
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

    it "hides the Monthly reports row when there are no monthly reports" do
      organization = Organization.create!(valid_attributes)
      get edit_organization_url(organization)
      expect(response.body).not_to include("Monthly reports")
    end

    it "shows the Monthly reports row when monthly reports exist" do
      organization = Organization.create!(valid_attributes)
      create(:monthly_report, organization: organization)
      get edit_organization_url(organization)
      expect(response.body).to include("Monthly reports")
    end

    it "shows the program status in the affiliations section" do
      organization = Organization.create!(valid_attributes)
      create(:affiliation, organization: organization, person: create(:person), title: "Facilitator")

      get edit_organization_url(organization)

      page = Capybara.string(response.body)
      expect(page).to have_content("Program status")
      expect(page).to have_css("span[title='Ongoing']", text: "O")
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

        expect(response).to redirect_to(edit_organization_url(organization))
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

    context "when the organization has event registrations" do
      it "does not destroy and redirects with an alert" do
        organization = Organization.create!(valid_attributes)
        create(:event_registration_organization, organization: organization)

        expect {
          delete organization_url(organization)
        }.not_to change(Organization, :count)

        expect(response).to redirect_to(edit_organization_url(organization))
        expect(flash[:alert]).to include("Unable to delete this organization")
      end

      it "renders the alert on the page after following the redirect" do
        organization = Organization.create!(valid_attributes)
        create(:event_registration_organization, organization: organization)

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

        expect(response).to redirect_to(edit_organization_url(organization))
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
