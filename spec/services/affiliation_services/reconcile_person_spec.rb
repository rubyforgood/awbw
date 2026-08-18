require "rails_helper"

RSpec.describe AffiliationServices::ReconcilePerson do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }

  # A facilitator-training registration for `person` linking `organization`.
  def training_registration(status:, ended: true)
    event = create(:event, *(ended ? [ :ended ] : []), facilitator_training: true)
    reg = create(:event_registration, registrant: person, event: event, status: status)
    create(:event_registration_organization, event_registration: reg, organization: organization)
    reg
  end

  # A "Facilitator" affiliation for (person, organization) owned by `registration`.
  def owned_facilitator(registration:, start_date: 1.month.ago.to_date)
    create(:affiliation,
           person: person,
           organization: organization,
           title: "Facilitator",
           start_date: start_date,
           event_registration: registration)
  end

  def reconcile(registration, **options)
    described_class.call(person: person, organization: organization, event: registration.event, **options)
  end

  describe "deactivation" do
    it "same-days the owned facilitator affiliation when the person never attended" do
      reg = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: reg)

      reconcile(reg)
      affiliation.reload

      expect(affiliation.end_date).to eq(affiliation.start_date)
      expect(affiliation).to be_inactive
      expect(affiliation).not_to be_active
    end

    %w[ incomplete_attendance registered cancelled transferred_out ].each do |status|
      it "deactivates when the only registration is #{status}" do
        reg = training_registration(status: status)
        affiliation = owned_facilitator(registration: reg)

        reconcile(reg)

        expect(affiliation.reload).not_to be_active
      end
    end

    it "deactivates on the day a one-day training ends, when the affiliation starts that same day" do
      event = create(:event, facilitator_training: true, start_date: 3.hours.ago,
                     end_date: 1.hour.ago, registration_close_date: 4.hours.ago)
      reg = create(:event_registration, registrant: person, event: event, status: "no_show")
      create(:event_registration_organization, event_registration: reg, organization: organization)
      affiliation = owned_facilitator(registration: reg, start_date: Date.current)

      reconcile(reg)

      expect(affiliation.reload).not_to be_active
    end

    it "leaves an assumptive affiliation alone while its training is still upcoming" do
      reg = training_registration(status: "registered", ended: false)
      affiliation = owned_facilitator(registration: reg, start_date: Date.current)

      reconcile(reg)

      expect(affiliation.reload).to be_active
      expect(affiliation.end_date).to be_nil
    end

    it "leaves an unowned (hand-created) facilitator affiliation untouched" do
      reg = training_registration(status: "no_show")
      hand_created = create(:affiliation, person: person, organization: organization,
                            title: "Facilitator", start_date: 1.month.ago.to_date)

      reconcile(reg)

      expect(hand_created.reload).to be_active
      expect(hand_created.end_date).to be_nil
    end

    it "reconciles a hand-created affiliation when the caller opts in" do
      reg = training_registration(status: "no_show")
      hand_created = create(:affiliation, person: person, organization: organization,
                            title: "Facilitator", start_date: 1.month.ago.to_date)

      reconcile(reg, include_unowned: true)

      expect(hand_created.reload).not_to be_active
    end
  end

  describe "keeping / activating" do
    it "keeps the affiliation active when the person attended" do
      reg = training_registration(status: "attended")
      affiliation = owned_facilitator(registration: reg)

      reconcile(reg)

      expect(affiliation.reload).to be_active
      expect(affiliation.end_date).to be_nil
    end

    it "keeps active when the person no-showed one training but attended another for the same org" do
      no_show = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: no_show)
      training_registration(status: "attended")

      reconcile(no_show)

      expect(affiliation.reload).to be_active
    end

    it "reactivates a previously same-day'd affiliation once the person is marked attended" do
      reg = training_registration(status: "attended")
      affiliation = owned_facilitator(registration: reg, start_date: 1.month.ago.to_date)
      affiliation.update!(end_date: affiliation.start_date)
      expect(affiliation.reload).not_to be_active

      reconcile(reg)

      expect(affiliation.reload).to be_active
      expect(affiliation.end_date).to be_nil
    end
  end

  describe "creating" do
    it "creates the missing facilitator affiliation for an attendee" do
      reg = training_registration(status: "attended")

      expect { described_class.call(person: person, organization: organization, event: reg.event, registration: reg) }
        .to change { person.affiliations.facilitators.where(organization: organization).count }.by(1)
    end

    it "proposes nothing when the caller passes no registration to own the new row" do
      reg = training_registration(status: "attended")

      plan = described_class.new(person: person, organization: organization, event: reg.event).plan

      expect(plan).to be_empty
    end
  end

  describe "idempotence" do
    it "is stable across repeated runs" do
      reg = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: reg)

      reconcile(reg)
      first = affiliation.reload.end_date
      reconcile(reg)

      expect(affiliation.reload.end_date).to eq(first)
    end
  end

  describe "#plan (dry run)" do
    it "reports :deactivate without writing" do
      reg = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: reg)

      plan = described_class.new(person: person, organization: organization, event: reg.event).plan

      expect(plan.map(&:action)).to eq([ :deactivate ])
      expect(affiliation.reload).to be_active
    end

    it "reports the reason a row needs no action" do
      reg = training_registration(status: "attended")
      owned_facilitator(registration: reg)

      plan = described_class.new(person: person, organization: organization, event: reg.event).plan

      expect(plan.map(&:action)).to eq([ :noop ])
      expect(plan.first.reason).to eq(described_class::ACTIVE_ATTENDED)
      expect(plan.first).not_to be_actionable
    end

    it "plans nothing when there is no owned facilitator affiliation" do
      reg = training_registration(status: "no_show")

      plan = described_class.new(person: person, organization: organization, event: reg.event).plan

      expect(plan).to be_empty
    end
  end

  describe "a non-training event" do
    it "deletes only the facilitator affiliation auto-created off that event" do
      event = create(:event, :ended, facilitator_training: false)
      reg = create(:event_registration, registrant: person, event: event, status: "attended")
      create(:event_registration_organization, event_registration: reg, organization: organization)
      off_this_event = owned_facilitator(registration: reg)
      hand_created = create(:affiliation, person: person, organization: organization,
                            title: "Facilitator", start_date: 2.years.ago.to_date)

      reconcile(reg)

      expect(Affiliation.exists?(off_this_event.id)).to be(false)
      expect(hand_created.reload).to be_active
    end
  end
end
