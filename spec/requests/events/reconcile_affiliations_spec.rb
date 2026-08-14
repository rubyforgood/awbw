require "rails_helper"

RSpec.describe "Events::ReconcileAffiliations", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:organization) { create(:organization) }
  let(:event) { create(:event, :ended, facilitator_training: true) }

  # A registrant of `event` who linked `organization`, with an owned facilitator
  # affiliation created (as the registration flow would).
  def registrant_with_affiliation(status:)
    person = create(:person)
    reg = create(:event_registration, event: event, registrant: person, status: status)
    create(:event_registration_organization, event_registration: reg, organization: organization)
    affiliation = create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", start_date: 1.month.ago.to_date,
                         event_registration: reg)
    [ person, affiliation ]
  end

  before { sign_in admin }

  describe "GET index" do
    it "previews the no-show as a deactivation, checked by default" do
      person, _affiliation = registrant_with_affiliation(status: "no_show")

      get reconcile_affiliations_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person.name)
      expect(response.body).to include("Will be deactivated")
    end

    it "redirects for a non-training event" do
      non_training = create(:event, :ended, facilitator_training: false)

      get reconcile_affiliations_event_path(non_training)

      expect(response).to redirect_to(registrants_event_path(non_training))
    end

    it "denies a non-admin" do
      sign_in create(:user)

      get reconcile_affiliations_event_path(event)

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "POST create" do
    it "deactivates the included non-completer and stamps the event" do
      _person, affiliation = registrant_with_affiliation(status: "no_show")
      key = AffiliationServices::ReconcileEvent.key_for(affiliation.person, organization)

      post reconcile_affiliations_event_path(event), params: { included: [ key ] }

      expect(response).to redirect_to(registrants_event_path(event))
      expect(affiliation.reload).not_to be_active
      expect(event.reload.affiliations_reconciled_at).to be_present
    end

    it "spares an opted-out row" do
      _person, affiliation = registrant_with_affiliation(status: "no_show")

      post reconcile_affiliations_event_path(event), params: { included: [] }

      expect(affiliation.reload).to be_active
    end
  end
end
