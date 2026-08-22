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

  describe "GET index" do
    before { sign_in admin }

    it "reports a clean bill of health when nothing is wrong" do
      get admin_data_health_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Everything checks out")
    end

    it "lists an offending row with enough context to recognise it" do
      offending_affiliation

      get admin_data_health_path

      expect(response.body).to include("Facilitator affiliations from non-training events")
      expect(response.body).to include(person.name)
      expect(response.body).to include("Community Potluck")
      expect(response.body).not_to include("Everything checks out")
    end

    it "offers a repair only for checks that have one" do
      offending_affiliation

      get admin_data_health_path

      expect(response.body).to include("Delete them")
      expect(response.body).to include("Review by hand")
    end
  end

  describe "POST repair" do
    before { sign_in admin }

    it "applies the fix and says what it did" do
      affiliation = offending_affiliation

      post admin_data_health_repair_path(check: "facilitator_affiliations_from_non_trainings")

      expect(response).to redirect_to(admin_data_health_path)
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
