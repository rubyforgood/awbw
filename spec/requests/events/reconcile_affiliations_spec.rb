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

    it "lists a no-action registrant under Not reconciled with the reason and attendance status" do
      person, _affiliation = registrant_with_affiliation(status: "attended")

      get reconcile_affiliations_event_path(event)

      expect(response.body).to include("Not reconciled")
      expect(response.body).to include("Active — attended")
      expect(response.body).to include("Attended")
      expect(response.body).to include(person.name)
    end

    it "reconciles a hand-entered (unowned) facilitator affiliation too" do
      person = create(:person)
      reg = create(:event_registration, event: event, registrant: person, status: "no_show")
      create(:event_registration_organization, event_registration: reg, organization: organization)
      create(:affiliation, person: person, organization: organization, title: "Facilitator", start_date: 1.year.ago.to_date)

      get reconcile_affiliations_event_path(event)

      expect(response.body).to include("Will be deactivated")
    end

    it "denies a non-admin" do
      sign_in create(:user)

      get reconcile_affiliations_event_path(event)

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "toggling attendance from the reconcile page" do
    it "stays on the reconcile page with a flash instead of leaving for the roster" do
      person, _affiliation = registrant_with_affiliation(status: "no_show")
      registration = person.event_registrations.first

      patch event_registration_path(registration, return_to: "reconcile_affiliations"),
            params: { event_registration: { status: "attended" } }

      expect(response).to redirect_to(reconcile_affiliations_event_path(event))
      expect(flash[:notice]).to be_present
    end
  end

  describe "POST confirm (preview changes)" do
    it "shows the selected change without writing" do
      _person, affiliation = registrant_with_affiliation(status: "no_show")

      post reconcile_affiliations_event_path(event), params: { included: [ "aff:#{affiliation.id}" ] }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Confirm affiliation changes")
      expect(response.body).to include("Perform changes")
      expect(affiliation.reload).to be_active
    end

    it "redirects back when nothing is selected" do
      registrant_with_affiliation(status: "no_show")

      post reconcile_affiliations_event_path(event), params: { included: [] }

      expect(response).to redirect_to(reconcile_affiliations_event_path(event))
    end
  end

  describe "POST perform" do
    it "deactivates the included non-completer and stamps the event" do
      _person, affiliation = registrant_with_affiliation(status: "no_show")

      post perform_reconcile_affiliations_event_path(event), params: { included: [ "aff:#{affiliation.id}" ] }

      expect(response).to redirect_to(registrants_event_path(event))
      expect(affiliation.reload).not_to be_active
      expect(event.reload.affiliations_reconciled_at).to be_present
    end

    it "spares an opted-out row" do
      _person, affiliation = registrant_with_affiliation(status: "no_show")

      post perform_reconcile_affiliations_event_path(event), params: { included: [] }

      expect(affiliation.reload).to be_active
    end

    it "creates a missing affiliation before the event when included" do
      upcoming = create(:event, facilitator_training: true, start_date: 3.days.from_now, end_date: 5.days.from_now)
      person = create(:person)
      reg = create(:event_registration, event: upcoming, registrant: person, status: "registered")
      create(:event_registration_organization, event_registration: reg, organization: organization)

      expect {
        post perform_reconcile_affiliations_event_path(upcoming), params: { included: [ "create:#{person.id}:#{organization.id}" ] }
      }.to change { person.affiliations.facilitators.where(organization: organization).count }.by(1)
    end

    it "deletes instead of same-daying when the delete option is checked" do
      _person, affiliation = registrant_with_affiliation(status: "no_show")
      key = "aff:#{affiliation.id}"

      post perform_reconcile_affiliations_event_path(event), params: { included: [ key ], delete: [ key ] }

      expect(Affiliation.exists?(affiliation.id)).to be(false)
    end

    it "deactivates a hand-entered facilitator affiliation when included" do
      person = create(:person)
      reg = create(:event_registration, event: event, registrant: person, status: "no_show")
      create(:event_registration_organization, event_registration: reg, organization: organization)
      hand_entered = create(:affiliation, person: person, organization: organization, title: "Facilitator", start_date: 1.year.ago.to_date)

      post perform_reconcile_affiliations_event_path(event), params: { included: [ "aff:#{hand_entered.id}" ] }

      expect(hand_entered.reload).not_to be_active
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

      post perform_reconcile_affiliations_event_path(non_training), params: { included: [ "aff:#{facilitator.id}" ] }

      expect(Affiliation.exists?(facilitator.id)).to be(false)
      expect(Affiliation.exists?(job.id)).to be(true)
    end
  end
end
