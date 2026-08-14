require "rails_helper"

RSpec.describe AffiliationServices::ReconcileFacilitatorAffiliation do
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

  describe "deactivation" do
    it "same-days the owned facilitator affiliation when the person never attended" do
      reg = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: reg)

      described_class.call(person: person, organization: organization)
      affiliation.reload

      expect(affiliation.end_date).to eq(affiliation.start_date)
      expect(affiliation).to be_inactive
      expect(affiliation).not_to be_active
    end

    %w[ incomplete_attendance registered cancelled transferred_out ].each do |status|
      it "deactivates when the only registration is #{status}" do
        reg = training_registration(status: status)
        affiliation = owned_facilitator(registration: reg)

        described_class.call(person: person, organization: organization)

        expect(affiliation.reload).not_to be_active
      end
    end

    it "leaves an assumptive affiliation alone while its training is still upcoming" do
      reg = training_registration(status: "registered", ended: false)
      affiliation = owned_facilitator(registration: reg, start_date: Date.current)

      described_class.call(person: person, organization: organization)

      expect(affiliation.reload).to be_active
      expect(affiliation.end_date).to be_nil
    end

    it "leaves an unowned (hand-created) facilitator affiliation untouched" do
      training_registration(status: "no_show")
      hand_created = create(:affiliation, person: person, organization: organization,
                            title: "Facilitator", start_date: 1.month.ago.to_date)

      described_class.call(person: person, organization: organization)

      expect(hand_created.reload).to be_active
      expect(hand_created.end_date).to be_nil
    end
  end

  describe "keeping / activating" do
    it "keeps the affiliation active when the person attended" do
      reg = training_registration(status: "attended")
      affiliation = owned_facilitator(registration: reg)

      described_class.call(person: person, organization: organization)

      expect(affiliation.reload).to be_active
      expect(affiliation.end_date).to be_nil
    end

    it "keeps active when the person no-showed one training but attended another for the same org" do
      no_show = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: no_show)
      training_registration(status: "attended")

      described_class.call(person: person, organization: organization)

      expect(affiliation.reload).to be_active
    end

    it "reactivates a previously same-day'd affiliation once the person is marked attended" do
      reg = training_registration(status: "attended")
      affiliation = owned_facilitator(registration: reg, start_date: 1.month.ago.to_date)
      affiliation.update!(end_date: affiliation.start_date)
      expect(affiliation.reload).not_to be_active

      described_class.call(person: person, organization: organization)

      expect(affiliation.reload).to be_active
      expect(affiliation.end_date).to be_nil
    end
  end

  describe "idempotence" do
    it "is stable across repeated runs" do
      reg = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: reg)

      described_class.call(person: person, organization: organization)
      first = affiliation.reload.end_date
      described_class.call(person: person, organization: organization)

      expect(affiliation.reload.end_date).to eq(first)
    end
  end

  describe "#plan (dry run)" do
    it "reports :deactivate without writing" do
      reg = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: reg)

      plan = described_class.new(person: person, organization: organization).plan

      expect(plan).to eq(:deactivate)
      expect(affiliation.reload).to be_active
    end

    it "reports :noop when there is no owned facilitator affiliation" do
      training_registration(status: "no_show")

      plan = described_class.new(person: person, organization: organization).plan

      expect(plan).to eq(:noop)
    end
  end
end
