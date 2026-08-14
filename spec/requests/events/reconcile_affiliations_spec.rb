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

    it "previews a missing affiliation as a creation before the event" do
      upcoming = create(:event, facilitator_training: true, start_date: 3.days.from_now, end_date: 5.days.from_now)
      person = create(:person)
      reg = create(:event_registration, event: upcoming, registrant: person, status: "registered")
      create(:event_registration_organization, event_registration: reg, organization: organization)

      get reconcile_affiliations_event_path(upcoming)

      expect(response.body).to include("Will be created")
    end

    it "previews a facilitator affiliation on a non-training event as a deletion" do
      non_training = create(:event, :ended, facilitator_training: false)
      person = create(:person)
      reg = create(:event_registration, event: non_training, registrant: person, status: "attended")
      create(:event_registration_organization, event_registration: reg, organization: organization)
      create(:affiliation, person: person, organization: organization, title: "Facilitator",
             start_date: 1.month.ago.to_date, event_registration: reg)

      get reconcile_affiliations_event_path(non_training)

      expect(response.body).to include("Will be deleted")
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

    it "creates a missing affiliation before the event when included" do
      upcoming = create(:event, facilitator_training: true, start_date: 3.days.from_now, end_date: 5.days.from_now)
      person = create(:person)
      reg = create(:event_registration, event: upcoming, registrant: person, status: "registered")
      create(:event_registration_organization, event_registration: reg, organization: organization)
      key = AffiliationServices::ReconcileEvent.key_for(person, organization)

      expect {
        post reconcile_affiliations_event_path(upcoming), params: { included: [ key ] }
      }.to change { person.affiliations.facilitators.where(organization: organization).count }.by(1)
    end

    it "deletes instead of same-daying when the delete option is checked" do
      _person, affiliation = registrant_with_affiliation(status: "no_show")
      key = AffiliationServices::ReconcileEvent.key_for(affiliation.person, organization)

      post reconcile_affiliations_event_path(event), params: { included: [ key ], delete: [ key ] }

      expect(Affiliation.exists?(affiliation.id)).to be(false)
    end

    it "deletes a facilitator affiliation auto-created off a non-training event, keeping the job affiliation" do
      non_training = create(:event, :ended, facilitator_training: false)
      person = create(:person)
      reg = create(:event_registration, event: non_training, registrant: person, status: "attended")
      create(:event_registration_organization, event_registration: reg, organization: organization)
      facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                           start_date: 1.month.ago.to_date, event_registration: reg)
      job = create(:affiliation, person: person, organization: organization, title: "Counselor",
                   event_registration: reg)
      key = AffiliationServices::ReconcileEvent.key_for(person, organization)

      post reconcile_affiliations_event_path(non_training), params: { included: [ key ] }

      expect(Affiliation.exists?(facilitator.id)).to be(false)
      expect(Affiliation.exists?(job.id)).to be(true)
    end
  end
end
