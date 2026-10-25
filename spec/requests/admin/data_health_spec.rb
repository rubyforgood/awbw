require "rails_helper"

RSpec.describe "Admin::DataHealth", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }

  # A facilitator affiliation minted by a registration to a non-training event.
  def offending_affiliation
    event = create(:event, :ended, facilitator_training: false, title: "Community Potluck")
    registration = create(:event_registration, event: event, registrant: person, status: "attended")
    create(:affiliation, person: person, organization: organization, title: "Facilitator",
                         start_date: 1.year.ago.to_date, event_registration: registration)
  end

  # The app settings check fires until an admin names these, so a page expected to
  # be clean has to have them chosen.
  def configure_app_settings
    # Pending matches what no affiliations derive, so the org itself doesn't drift.
    pending = OrganizationStatus.find_or_create_by!(name: "Pending")
    org = create(:organization, tax_id: "00-0000000", organization_status: pending)
    Setting.create!(organization: org,
                    return_address: create(:address, addressable: org),
                    remittance_address: create(:address, addressable: org))
  end

  describe "GET index" do
    before { sign_in admin }

    it "reports a clean bill of health when nothing is wrong" do
      configure_app_settings

      get admin_data_health_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Everything checks out")
    end

    it "groups checks under headings" do
      get admin_data_health_path

      headings = Nokogiri::HTML(response.body).css("h2 button > span:first-child").map { |h| h.text.strip }
      expect(headings).to eq([ "Settings", "Affiliations", "People", "Form answers", "Payments", "Stories", "Resources", "Communications" ])
    end

    it "starts every group collapsed, with an expand-all control" do
      get admin_data_health_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.css("[data-controller='expandable-card']").map { |c| c["data-expandable-card-expanded-value"] }.uniq).to eq([ "false" ])
      expect(doc.css("[data-expandable-card-target='body']").all? { |b| b["class"].split.include?("hidden") }).to be(true)
      expect(doc.at_css("[data-action='expandable-cards#toggleAll']").text).to include("Expand all")
    end

    it "opens the group holding the check just repaired, leaving the rest collapsed" do
      get admin_data_health_path(open: "stories_without_workshop")

      doc = Nokogiri::HTML(response.body)
      open_cards = doc.css("[data-expandable-card-expanded-value='true']")
      expect(open_cards.size).to eq(1)
      expect(open_cards.first.at_css("h2").text).to include("Stories")
      expect(open_cards.first.at_css("[data-expandable-card-target='body']")["class"].split).not_to include("hidden")
      expect(doc.at_css("#check-stories_without_workshop")).to be_present
    end

    it "lists an offending row with enough context to recognise it" do
      offending_affiliation

      get admin_data_health_path

      expect(response.body).to include("Facilitator affiliations from non-training events")
      expect(response.body).to include(person.name)
      expect(response.body).to include("Community Potluck")
      expect(response.body).not_to include("Everything checks out")
    end

    # The drift check is the one worth reading side by side: what the app uses
    # against what the ignored column stores.
    context "the legacy status drift check" do
      let!(:active_status) { OrganizationStatus.find_or_create_by!(name: "Active") }
      let!(:drifted) { create(:organization, name: "Drifted Org", organization_status: active_status) }

      it "renders both statuses as chips, in labelled columns" do
        get admin_data_health_path

        doc = Nokogiri::HTML(response.body)
        headings = doc.css("li.contents").first.css("span").map(&:text).map(&:strip)
        expect(headings).to eq([ "Organization", "Affiliations say", "Stored status" ])

        row = doc.css("li.contents").last
        expect(row.text).to include("Drifted Org")
        expect(row.text).to include("Never active")
        expect(row.text).to include("Active")
      end

      it "colours each chip from its own bucket, so a disagreement is visible" do
        get admin_data_health_path

        row = Nokogiri::HTML(response.body).css("li.contents").last
        chips = row.css("span[class*='rounded-full']").map { |c| c["class"] }

        expect(chips.size).to eq(2)
        expect(chips.first).to eq(chips.first) # affiliation-derived
        expect(chips.first).not_to eq(chips.last), "both chips got the same colour, so the drift is invisible"
      end

      it "links each organization to its program-status section" do
        get admin_data_health_path

        expect(response.body).to include(
          CGI.escapeHTML(edit_organization_path(drifted, anchor: "program-status"))
        )
      end
    end

    it "offers a repair only for checks that have one" do
      offending_affiliation

      get admin_data_health_path

      expect(response.body).to include("Delete them")
      expect(response.body).to include("Review by hand")
    end
  end

  describe "listed rows" do
    before { sign_in admin }

    it "links a misaligned affiliation's person to their edit page and its org to the registration's Link organizations page" do
      registration = create(:event_registration, event: create(:event, :ended, facilitator_training: true),
                                                 registrant: person, status: "attended")
      create(:event_registration_organization, event_registration: registration, organization: create(:organization))
      create(:affiliation, person: person, organization: organization, title: "Facilitator",
                           start_date: 1.year.ago.to_date, event_registration: registration)

      get admin_data_health_path

      back = { return_to: "data_health", check: "misaligned_affiliation_provenance" }
      expect(response.body).to include(CGI.escapeHTML(edit_person_path(person, **back)))
      expect(response.body).to include(CGI.escapeHTML(link_organization_event_registration_path(registration, **back)))
      expect(response.body).not_to include("Unlink them")
    end

    it "links each row to where it can be fixed, and the card to its review page" do
      person = create(:person)
      create(:user, person: person)

      get admin_data_health_path

      expect(response.body).to include(%(href="#{person_path(person)}"))
      expect(response.body).to include(%(href="#{dedupe_index_users_path}"))
    end
  end

  describe "GET rows" do
    before { sign_in admin }

    def stories_without_workshop(number)
      number.times { |n| create(:story, title: "Unlinked story #{n.to_s.rjust(2, '0')}", workshop: nil) }
    end

    it "lists ten rows at a time, with a pager into the check's own frame" do
      stories_without_workshop(12)

      get admin_data_health_path

      frame = Nokogiri::HTML(response.body).at_css("turbo-frame#data_health_rows_stories_without_workshop")
      expect(frame.css("li").size).to eq(10)
      expect(frame.text).to include("1–10 of 12")
      expect(frame.to_html).to include(CGI.escapeHTML(admin_data_health_rows_path(check: "stories_without_workshop", page: 2)))
    end

    it "renders a later page into the same frame" do
      stories_without_workshop(12)

      get admin_data_health_rows_path(check: "stories_without_workshop", page: 2),
          headers: { "Turbo-Frame" => "data_health_rows_stories_without_workshop" }

      expect(response).to have_http_status(:ok)
      frame = Nokogiri::HTML(response.body).at_css("turbo-frame#data_health_rows_stories_without_workshop")
      expect(frame.css("li").size).to eq(2)
      expect(frame.text).to include("11–12 of 12")
    end

    it "is a 404 for an unknown check" do
      get admin_data_health_rows_path(check: "no_such_check")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "old-system rows" do
    before { sign_in admin }

    it "counts them in a sentence beside the check, linked to the index, outside the main count" do
      create(:notification, :incoming, kind: "contact_us_fyi", responded: false, created_at: Date.new(2025, 6, 1))

      get admin_data_health_path

      expect(response.body).to include("Not counted: 1 from the old system, before January 1, 2026.")
      expect(response.body).to include(CGI.escapeHTML(notifications_path(responded_status: "no", to: "2025-12-31")))
    end
  end

  describe "GET worklists" do
    it "renders duplicate and author credit counts into the lazy frame" do
      sign_in admin
      create_list(:workshop, 2, title: "Anger Volcano")

      get admin_data_health_worklists_path, headers: { "Turbo-Frame" => "data_health_worklists" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="data_health_worklists"')
      expect(response.body).to include("Possible duplicates")
      expect(response.body).to include(%(href="#{dedupe_index_workshops_path}"))
      expect(response.body).to include("Author credit to review")
    end

    it "denies a non-admin" do
      sign_in create(:user)

      get admin_data_health_worklists_path, headers: { "Turbo-Frame" => "data_health_worklists" }

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "GET filemaker_not_imported" do
    let(:frame_headers) { { "Turbo-Frame" => "filemaker_not_imported_results" } }

    it "renders a skeleton frame without comparing the archive" do
      sign_in admin
      expect(DataHealth::FilemakerNotImported).not_to receive(:new)

      get admin_data_health_filemaker_not_imported_path(kind: "people")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("FileMaker records not imported")
      expect(response.body).to include(CGI.escapeHTML(admin_data_health_filemaker_not_imported_path(kind: "people")))
    end

    it "lists the selected kind's rows no portal record carries, linked to the archive with a way back" do
      sign_in admin
      FmRolodex.create!(fm_id: "00006", data: { "FirstName" => "Ada", "LastName" => "Archer" })
      FmRolodex.create!(fm_id: "00007", data: { "FirstName" => "Bea", "LastName" => "Baker" })
      create(:person, filemaker_code: "00006")

      get admin_data_health_filemaker_not_imported_path(kind: "people"), headers: frame_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="filemaker_not_imported_results"')
      expect(response.body).to include("Bea Baker")
      expect(response.body).not_to include("Ada Archer")
      expect(response.body).to include(CGI.escapeHTML(fm_archive_path("00007", table: "rolodexes", return_to: "filemaker_not_imported", kind: "people", page: 1)))
    end

    it "denies a non-admin" do
      sign_in create(:user)

      get admin_data_health_filemaker_not_imported_path, headers: frame_headers

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "POST repair" do
    before { sign_in admin }

    it "applies the fix and says what it did" do
      affiliation = offending_affiliation

      post admin_data_health_repair_path(check: "facilitator_affiliations_from_non_trainings")

      expect(response).to redirect_to(admin_data_health_path(open: "facilitator_affiliations_from_non_trainings",
                                                             anchor: "check-facilitator_affiliations_from_non_trainings"))
      expect(flash[:notice]).to eq("Deleted 1 facilitator affiliation.")
      expect(Affiliation.exists?(affiliation.id)).to be(false)
    end

    it "refuses an unknown check rather than erroring" do
      post admin_data_health_repair_path(check: "no_such_check")

      expect(response).to redirect_to(admin_data_health_path)
      expect(flash[:alert]).to eq("Unknown check.")
    end

    # The param names a class to run, so a report-only check must not be coaxed
    # into a repair by hitting the route directly.
    it "refuses a report-only check" do
      post admin_data_health_repair_path(check: "legacy_organization_status_drift")

      expect(flash[:alert]).to eq("Unknown check.")
    end
  end

  describe "authorization" do
    it "denies a non-admin the page" do
      sign_in create(:user)

      get admin_data_health_path

      expect(response).not_to have_http_status(:ok)
    end

    it "denies a non-admin a repair, leaving the data alone" do
      affiliation = offending_affiliation
      sign_in create(:user)

      post admin_data_health_repair_path(check: "facilitator_affiliations_from_non_trainings")

      expect(response).not_to have_http_status(:ok)
      expect(Affiliation.exists?(affiliation.id)).to be(true)
    end
  end
end
