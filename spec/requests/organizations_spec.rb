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

    it "renders the results frame with deduped age groups from affiliated people" do
      organization = Organization.create!(valid_attributes)
      age_type = create(:category_type, name: "AgeRange", published: true)
      teen = create(:category, :published, category_type: age_type, name: "13-17")
      person = create(:person)
      create(:affiliation, organization: organization, person: person)
      person.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])

      get organizations_url, headers: { "Turbo-Frame" => "organizations_results" }

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

    it "shows the parent link and nested children on the profile" do
      parent = Organization.create!(valid_attributes.merge(name: "Roof Org"))
      organization = Organization.create!(valid_attributes.merge(name: "Adult Windows"))
      organization.update!(parent: parent)
      child = Organization.create!(valid_attributes.merge(name: "Childrens Windows", parent: organization))

      get organization_url(organization)
      expect(response.body).to include("Part of")
      expect(response.body).to include("Roof Org")
      expect(response.body).to include("Nested organizations")
      expect(response.body).to include(child.name)
    end

    it "shows age groups on the profile, gated by profile_show_age_ranges" do
      organization = Organization.create!(valid_attributes)
      age_type = create(:category_type, name: "AgeRange", published: true)
      teen = create(:category, :published, category_type: age_type, name: "13-17")
      person = create(:person)
      create(:affiliation, organization: organization, person: person)
      person.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])

      get organization_url(organization)
      expect(response.body).to include("13-17")

      organization.update!(profile_show_age_ranges: false)
      get organization_url(organization)
      expect(response.body).not_to include("13-17")
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
      org = create(:organization, organization_status: organization_status)
      create(:sectorable_item, sector: create(:sector, name: "Direct Sector 1"), sectorable: org)
      %w[Alpha Bravo Charlie Delta].each do |name|
        person = create(:person)
        create(:sectorable_item, sector: create(:sector, name: name), sectorable: person, is_primary: true)
        create(:affiliation, organization: org, person: person)
      end
      former = create(:person)
      create(:sectorable_item, sector: create(:sector, name: "Former Sector"), sectorable: former, is_primary: true)
      create(:affiliation, organization: org, person: former, end_date: 1.year.ago)
      org
    end

    it "shows the three most-held facilitator primaries, starred, then links to the full list" do
      second_delta = create(:person)
      create(:sectorable_item, sector: Sector.find_by!(name: "Delta"), sectorable: second_delta, is_primary: true)
      create(:affiliation, organization: organization_with_sectors, person: second_delta)

      get organization_url(organization_with_sectors)

      page = Capybara.string(response.body)
      expect(page.all("a[data-sector-name]").map { |chip| chip["data-sector-name"] }).to eq(%w[Delta Alpha Bravo])
      expect(page).to have_css("a[data-sector-name] i.fa-star", count: 3)
      expect(page).to have_link("+1 more", href: populations_served_organization_path(organization_with_sectors))
      expect(page).not_to have_content("Direct Sector 1")
      expect(page).not_to have_content("Former Sector")
    end

    it "lists every sector and age group active facilitators hold, primary and additional, on the breakdown page" do
      age_type = create(:category_type, name: "AgeRange", published: true)
      teen = create(:category, :published, category_type: age_type, name: "Teens")
      person = organization_with_sectors.affiliations.first.person
      create(:sectorable_item, sector: create(:sector, name: "Echo"), sectorable: person, is_primary: false)
      person.tag_age_groups(primary_ids: [], additional_ids: [ teen.id ])

      get populations_served_organization_url(organization_with_sectors)

      page = Capybara.string(response.body)
      expect(page).to have_content("Sectors and age groups")
      %w[Alpha Bravo Charlie Delta Echo Teens].each { |name| expect(page).to have_content(name) }
      expect(page).to have_css("li[title='1 total · 0 primary · 1 additional']", count: 2)
      expect(page).not_to have_content("Direct Sector 1")
      expect(page).not_to have_content("Former Sector")
    end

    it "sorts the breakdown by the chosen option, defaulting to primary first" do
      person = organization_with_sectors.affiliations.first.person
      %w[Echo Foxtrot].each { |name| create(:sectorable_item, sector: create(:sector, name: name), sectorable: person, is_primary: false) }
      second = create(:person)
      create(:affiliation, organization: organization_with_sectors, person: second)
      create(:sectorable_item, sector: Sector.find_by!(name: "Echo"), sectorable: second, is_primary: false)

      sector_order = -> { Capybara.string(response.body).all("section", text: "Sectors").first.all("li a").map(&:text) }

      get populations_served_organization_url(organization_with_sectors)
      expect(sector_order.call).to eq(%w[Alpha Bravo Charlie Delta Echo Foxtrot])
      expect(Capybara.string(response.body)).to have_css("a[aria-current='true']", exact_text: "Primary first")

      get populations_served_organization_url(organization_with_sectors, sort: "total")
      expect(sector_order.call).to eq(%w[Echo Alpha Bravo Charlie Delta Foxtrot])

      get populations_served_organization_url(organization_with_sectors, sort: "name")
      expect(sector_order.call).to eq(%w[Alpha Bravo Charlie Delta Echo Foxtrot])

      get populations_served_organization_url(organization_with_sectors, sort: "bogus")
      expect(Capybara.string(response.body)).to have_css("a[aria-current='true']", exact_text: "Primary first")
    end

    it "caps the edit page at three sectors with links to the breakdown that return to the edit page" do
      breakdown = populations_served_organization_path(organization_with_sectors, return_to: "organization_edit")

      get edit_organization_url(organization_with_sectors)

      page = Capybara.string(response.body)
      expect(page).to have_css("a[data-sector-name]", count: 3)
      expect(page).to have_link("+1 more", href: breakdown)
      expect(page).to have_link("See all sectors and age groups", href: breakdown)

      get breakdown
      expect(Capybara.string(response.body)).to have_link("Edit #{organization_with_sectors.name}", href: edit_organization_path(organization_with_sectors))
      expect(response.body).to include("return_to=organization_edit&amp;sort=total")
    end

    it "points the breakdown eyebrow at the profile by default" do
      get populations_served_organization_url(organization_with_sectors)

      expect(Capybara.string(response.body)).to have_link(organization_with_sectors.name, href: organization_path(organization_with_sectors))
    end

    it "shows the roll-up read-only on the edit page with a note on where it comes from" do
      get edit_organization_url(organization_with_sectors)

      page = Capybara.string(response.body)
      %w[Alpha Bravo Charlie].each { |name| expect(page).to have_content(name) }
      expect(page).not_to have_content("Direct Sector 1")
      expect(page).to have_content("Sectors and age groups aren't editable here")
      expect(page).not_to have_css("[name*='sectorable_items_attributes']")
      expect(page).not_to have_css("[name='organization[category_ids][]']")
    end

    describe "profile display preferences" do
      let!(:teen) do
        age_type = create(:category_type, name: "AgeRange", published: true)
        create(:category, :published, category_type: age_type, name: "Teens").tap do |category|
          organization_with_sectors.affiliations.first.person.tag_age_groups(primary_ids: [ category.id ], additional_ids: [])
        end
      end

      it "drops the breakdown section an organization hides on its profile" do
        organization_with_sectors.update!(profile_show_sectors: false)

        get populations_served_organization_url(organization_with_sectors)

        page = Capybara.string(response.body)
        expect(page).to have_css("h2", exact_text: "Age groups served")
        expect(page).not_to have_css("h2", exact_text: "Sectors")
        expect(page).not_to have_content("Alpha")
      end

      it "shows nothing to break down when both are hidden" do
        organization_with_sectors.update!(profile_show_sectors: false, profile_show_age_ranges: false)

        get populations_served_organization_url(organization_with_sectors)

        page = Capybara.string(response.body)
        expect(page).to have_content("This organization doesn't show sectors or age groups on its profile.")
        expect(page).not_to have_css("section h2")
        expect(page).not_to have_link("Primary first")
      end

      it "hides the profile and edit links to the breakdown when both are hidden" do
        organization_with_sectors.update!(profile_show_sectors: false, profile_show_age_ranges: false)

        get organization_url(organization_with_sectors)
        expect(Capybara.string(response.body)).not_to have_link("See all sectors and age groups")

        get edit_organization_url(organization_with_sectors)
        page = Capybara.string(response.body)
        expect(page).not_to have_link("See all sectors and age groups")
        expect(page).not_to have_link("+1 more")
        expect(page).to have_content("+1 more")
      end
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_organization_url
      expect(response).to be_successful
    end

    it "focuses the name field" do
      get new_organization_url

      expect(Capybara.string(response.body)).to have_css("textarea#organization_name[autofocus]")
    end
  end

  describe "GET /edit" do
    it "lists address phones under the phone editor, numbered by address when there are several" do
      organization = create(:organization)
      create(:address, addressable: organization, phone: "123-123-1234")
      create(:address, addressable: organization, phone: "123-332-1234")

      get edit_organization_url(organization)

      phones = Capybara.string(response.body).find("#phones")
      expect(phones).to have_text("On addresses")
      expect(phones).to have_css("li", text: "1. 123-123-1234")
      expect(phones).to have_css("li", text: "2. 123-332-1234")
    end

    it "edits the organization's own phone numbers beside them" do
      organization = create(:organization)
      organization.contact_methods.create!(kind: "phone", value: "555-0100")

      get edit_organization_url(organization)

      phones = Capybara.string(response.body).find("#phones")
      expect(phones).to have_field(with: "555-0100")
      expect(phones).to have_link("➕ Add phone")
    end

    it "leaves focus alone so in-page links keep their scroll position" do
      get edit_organization_url(create(:organization))

      expect(Capybara.string(response.body)).not_to have_css("textarea#organization_name[autofocus]")
    end

    it "opens and rings the address a person's work-address link points at, with a way back" do
      organization = create(:organization)
      address = create(:address, addressable: organization)
      other = create(:address, addressable: organization)
      person = create(:person)

      get edit_organization_url(organization, highlight_address: address.id, return_to: "person_edit", person_id: person.id)

      page = Capybara.string(response.body)
      expect(page).to have_css("details#address-#{address.id}[open].ring-yellow-500")
      expect(page).not_to have_css("details#address-#{other.id}[open]")
      expect(page).to have_link("Edit person", href: edit_person_path(person, anchor: "addresses"))
    end

    it "shows each address's phone on its collapsed header" do
      organization = create(:organization)
      create(:address, addressable: organization, phone: "123-123-1234")

      get edit_organization_url(organization)

      expect(Capybara.string(response.body)).to have_css("#addresses summary", text: "123-123-1234")
    end

    it "opens the other-type box when the org is typed Other" do
      organization = create(:organization, organization_type: Organization::ORGANIZATION_TYPE_OTHER, organization_type_other: "Equine therapy")

      get edit_organization_url(organization)

      expect(Capybara.string(response.body)).to have_css("details[open] summary", text: "Other type?")
    end

    it "renders a successful response" do
      organization = Organization.create!(valid_attributes)
      get edit_organization_url(organization)
      expect(response).to be_successful
    end

    it "shows (none) in the admin status select when the organization has no status" do
      organization = Organization.create!(valid_attributes.merge(organization_status_id: nil))
      get edit_organization_url(organization, admin: 1)

      status_select = Nokogiri::HTML(response.body).at_css("select[name='organization[organization_status_id]']")
      expect(status_select.at_css("option[selected]")).to be_nil
      expect(status_select.at_css("option[value='']").text).to eq("(none)")
    end

    it "hides the Monthly reports row when there are no monthly reports" do
      organization = Organization.create!(valid_attributes)
      get edit_organization_url(organization)
      expect(response.body).not_to include("Monthly reports")
    end

    it "links the parent-organization label to the parent's profile when one is set" do
      parent = Organization.create!(valid_attributes.merge(name: "Roof Org"))
      organization = Organization.create!(valid_attributes.merge(parent: parent))
      get edit_organization_url(organization)
      expect(response.body).to include(organization_path(parent))
      expect(response.body).to include("fa-arrow-up-right-from-square")
    end

    it "shows the Monthly reports row when monthly reports exist" do
      organization = Organization.create!(valid_attributes)
      create(:monthly_report, organization: organization)
      get edit_organization_url(organization)
      expect(response.body).to include("Monthly reports")
    end

    it "surfaces the affiliated-since note when it predates the facilitator start" do
      organization = Organization.create!(valid_attributes)
      create(:affiliation, organization: organization, person: create(:person),
                           title: "Volunteer", start_date: Date.new(2010, 1, 1))
      create(:affiliation, organization: organization, person: create(:person),
                           title: "Facilitator", start_date: Date.new(2015, 3, 1))

      get edit_organization_url(organization)

      expect(response.body).to include("Affiliated since Jan 2010")
    end

    it "renders per-event program-status chips only for facilitator-training events" do
      organization = Organization.create!(valid_attributes)
      create(:affiliation, organization: organization, person: create(:person),
                           title: "Facilitator", start_date: Date.new(2020, 1, 1))
      training = create(:event, title: "Qwultz Training", facilitator_training: true,
                                start_date: Date.new(2026, 8, 1))
      non_training = create(:event, title: "Zibberpicnic Social", facilitator_training: false,
                                    start_date: Date.new(2026, 8, 2))
      [ training, non_training ].each do |event|
        registration = create(:event_registration, registrant: create(:person), event: event, status: "registered")
        registration.event_registration_organizations.create!(organization: organization)
      end

      get edit_organization_url(organization)

      expect(response.body).to include("Qwultz Training")
      expect(response.body).not_to include("Zibberpicnic Social")
    end

    it "renders a red attendance chip for a training the org only registered for inactively" do
      organization = Organization.create!(valid_attributes)
      no_show_training = create(:event, title: "Skipped Training", abbreviation: "SKP101",
                                        facilitator_training: true, start_date: Date.new(2026, 8, 1))
      registration = create(:event_registration, registrant: create(:person),
                                                 event: no_show_training, status: "no_show")
      registration.event_registration_organizations.create!(organization: organization)

      get edit_organization_url(organization)

      chip = Capybara.string(response.body).all("span", text: /SKP101/).first
      expect(chip.native.text).to match(/No show .* SKP101/)
      expect(chip[:class]).to include("text-red-700")
    end

    it "keeps a training's program-status chip when the org has any active registration there" do
      organization = Organization.create!(valid_attributes)
      create(:affiliation, organization: organization, person: create(:person),
                           title: "Facilitator", start_date: Date.new(2020, 1, 1))
      training = create(:event, title: "Half Skipped", abbreviation: "HLF101",
                                facilitator_training: true, start_date: Date.new(2026, 8, 1))
      [ "registered", "no_show" ].each do |status|
        registration = create(:event_registration, registrant: create(:person), event: training, status: status)
        registration.event_registration_organizations.create!(organization: organization)
      end

      get edit_organization_url(organization)

      expect(response.body).to match(/Ongoing .* HLF101/)
      expect(response.body).not_to match(/No show .* HLF101/)
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

      it "updates the high_profile flag" do
        organization = Organization.create!(valid_attributes)
        patch organization_url(organization), params: { organization: { high_profile: "1" } }
        expect(organization.reload.high_profile).to be(true)
      end

      it "saves the organization's phones" do
        organization = Organization.create!(valid_attributes)
        patch organization_url(organization), params: { organization: { contact_methods_attributes: {
          "0" => { kind: "phone", contact_type: "work", value: "555-0100", primary: "1" }
        } } }
        expect(organization.contact_methods.sole).to have_attributes(value: "555-0100", contact_type: "work", primary: true)
      end

      it "nests the organization under a parent" do
        parent = Organization.create!(valid_attributes.merge(name: "Roof Org"))
        organization = Organization.create!(valid_attributes)
        patch organization_url(organization), params: { organization: { parent_id: parent.id } }
        expect(organization.reload.parent).to eq(parent)
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        organization = Organization.create!(valid_attributes)
        patch organization_url(organization), params: { organization: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "linking an affiliation to an organization address" do
      it "saves the chosen organization_address_id on the affiliation" do
        organization = Organization.create!(valid_attributes)
        address = create(:address, addressable: organization)
        person = create(:person)
        affiliation = create(:affiliation, organization: organization, person: person)

        patch organization_url(organization), params: {
          organization: {
            affiliations_attributes: {
              "0" => { id: affiliation.id, person_id: person.id, organization_address_id: address.id }
            }
          }
        }

        expect(affiliation.reload.organization_address_id).to eq(address.id)
      end
    end
  end

  describe "sector saving" do
    let!(:sector) { create(:sector, :published) }
    let(:organization) { Organization.create!(valid_attributes) }

    it "ignores submitted sectors" do
      patch organization_url(organization), params: {
        organization: {
          name: organization.name,
          sectorable_items_attributes: { "0" => { sector_id: sector.id, _destroy: "false" } }
        }
      }

      expect(organization.reload.sectors).to be_empty
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
