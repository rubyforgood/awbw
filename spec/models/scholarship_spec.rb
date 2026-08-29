require "rails_helper"

RSpec.describe Scholarship, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:recipient).class_name("Person") }
    it { is_expected.to belong_to(:grant).optional }
    it { is_expected.to have_one(:allocation).dependent(:destroy) }
  end

  describe "#event" do
    let(:person) { create(:person) }

    it "is the event behind the registration the allocation funds" do
      training = create(:event, title: "TAC251", facilitator_training: true)
      registration = create(:event_registration, event: training, registrant: person)
      scholarship = create(:scholarship, recipient: person)
      create(:allocation, source: scholarship, allocatable: registration, amount: 0)

      expect(scholarship.reload.event).to eq(training)
    end

    it "is nil for an award with no allocation behind it" do
      expect(create(:scholarship, recipient: person).event).to be_nil
    end
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than_or_equal_to(0) }

    describe "recipient_must_match_allocation_registrant" do
      let(:event) { create(:event) }
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event:, registrant: person) }

      it "is valid when recipient matches the allocation's registrant" do
        scholarship = build(:scholarship, recipient: person)
        scholarship.build_allocation(allocatable: registration, amount: scholarship.amount_cents)
        expect(scholarship).to be_valid
      end

      it "is invalid when recipient differs from the allocation's registrant" do
        other_person = create(:person)
        scholarship = build(:scholarship, recipient: other_person)
        scholarship.build_allocation(allocatable: registration, amount: scholarship.amount_cents)
        expect(scholarship).not_to be_valid
        expect(scholarship.errors[:recipient]).to include("must be the same person as the event registration's registrant")
      end
    end

    describe "allocation_must_be_valid" do
      let(:event) { create(:event, cost_cents: 10_000) }
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event:, registrant: person) }

      it "is invalid when a newly built allocation overshoots the remaining owed" do
        scholarship = build(:scholarship, recipient: person, amount_cents: 15_000)
        scholarship.build_allocation(allocatable: registration, amount: 15_000)

        expect(scholarship).not_to be_valid
        expect(scholarship.errors[:base]).to include(a_string_matching(/Cannot allocate more than remaining event cost/))
      end

      it "does not re-validate an already-persisted allocation on an unrelated re-save" do
        scholarship = create(:scholarship, recipient: person, amount_cents: 10_000)
        create(:allocation, source: scholarship, allocatable: registration, amount: 10_000)
        # Shrinking the event below the funded amount would fail the allocation's own
        # cost check — but a persisted allocation is out of scope, so saving an
        # unrelated attribute must still succeed.
        event.update!(cost_cents: 5_000)

        expect { scholarship.update!(agreement_signed: true) }.not_to raise_error
      end
    end

    describe "within_grant_budget" do
      let(:grant) { create(:grant, amount_cents: 100_000) }

      it "is valid when the amount stays within the grant's funds" do
        expect(build(:scholarship, grant:, amount_cents: 60_000)).to be_valid
      end

      it "is invalid when the amount exceeds the grant's funds" do
        scholarship = build(:scholarship, grant:, amount_cents: 150_000)
        expect(scholarship).not_to be_valid
        expect(scholarship.errors[:amount_cents]).to include("would exceed the grant's available funds")
      end

      it "accounts for other scholarships already drawn from the grant" do
        create(:scholarship, grant:, amount_cents: 70_000)
        scholarship = build(:scholarship, grant:, amount_cents: 40_000)
        expect(scholarship).not_to be_valid
      end

      it "is not constrained when no grant is set" do
        expect(build(:scholarship, grant: nil, amount_cents: 9_999_999)).to be_valid
      end
    end
  end

  describe "marking the event registration's scholarship_requested flag" do
    let(:event) { create(:event) }
    let(:person) { create(:person) }
    let(:registration) { create(:event_registration, event:, registrant: person, scholarship_requested: false) }

    it "sets scholarship_requested to true on the connected event registration" do
      scholarship = build(:scholarship, recipient: person)
      scholarship.build_allocation(allocatable: registration, amount: scholarship.amount_cents)
      scholarship.save!

      expect(registration.reload.scholarship_requested).to be(true)
    end

    it "leaves scholarship_requested true when the scholarship is destroyed" do
      scholarship = build(:scholarship, recipient: person)
      scholarship.build_allocation(allocatable: registration, amount: scholarship.amount_cents)
      scholarship.save!

      scholarship.destroy!

      expect(registration.reload.scholarship_requested).to be(true)
    end

    it "does nothing when the scholarship is not connected to an event registration" do
      expect { create(:scholarship, grant: create(:grant), recipient: person) }.not_to raise_error
    end
  end

  describe "agreement response status (pending → accepted → declined)" do
    it "starts pending" do
      scholarship = create(:scholarship)
      expect(scholarship.agreement_pending?).to be(true)
      expect(scholarship.agreement_signed?).to be(false)
      expect(scholarship.agreement_declined?).to be(false)
    end

    it "accepts via the virtual agreement_signed setter and stamps the time" do
      scholarship = create(:scholarship)

      scholarship.update!(agreement_signed: true)

      expect(scholarship.agreement_signed?).to be(true)
      expect(scholarship.latest_agreement_response.responded_at).to be_present
    end

    it "returns to pending when unsigned" do
      scholarship = create(:scholarship, agreement_signed: true)

      scholarship.update!(agreement_signed: false)

      expect(scholarship.agreement_signed?).to be(false)
      expect(scholarship.agreement_pending?).to be(true)
    end

    it "#accept_agreement! is idempotent (no duplicate history row)" do
      scholarship = create(:scholarship)
      scholarship.accept_agreement!

      expect { scholarship.accept_agreement! }.not_to change { scholarship.agreement_responses.count }
    end

    it "logs a response when the award is created already signed (the admin form's toggle)" do
      scholarship = create(:scholarship, agreement_signed: true)

      expect(scholarship.agreement_responses.count).to eq(1)
      expect(scholarship.latest_agreement_response).to have_attributes(status: "accepted")
      expect(scholarship.latest_agreement_response.responded_at).to be_present
    end

    it "logs nothing when the award is created pending" do
      expect(create(:scholarship).agreement_responses.count).to eq(0)
    end
  end

  describe "declining" do
    it "#decline_agreement! records the status, time, and reason" do
      scholarship = create(:scholarship)

      scholarship.decline_agreement!("Timing no longer works")

      expect(scholarship.agreement_declined?).to be(true)
      expect(scholarship.latest_agreement_response.responded_at).to be_present
      expect(scholarship.latest_agreement_response.reason).to eq("Timing no longer works")
    end

    it "#decline_agreement! clears any prior signed state (mutually exclusive)" do
      scholarship = create(:scholarship, agreement_signed: true)

      scholarship.decline_agreement!("Changed my mind")

      expect(scholarship.agreement_signed?).to be(false)
      expect(scholarship.agreement_declined?).to be(true)
    end

    it "#decline_agreement! stores nil for a blank reason" do
      scholarship = create(:scholarship)

      scholarship.decline_agreement!("")

      expect(scholarship.latest_agreement_response.reason).to be_nil
    end

    it "stays declined (allocation still zero) when only the amount is edited" do
      event = create(:event, cost_cents: 10_000)
      registration = create(:event_registration, event:)
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 5_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 5_000)
      scholarship.reload
      scholarship.decline_agreement!("No longer available")

      scholarship.update!(amount_cents: 6_000)

      # Editing the amount no longer reactivates a decline — that's the explicit
      # Re-offer action now.
      expect(scholarship.reload.agreement_declined?).to be(true)
      expect(scholarship.allocation.reload.amount).to eq(0)
    end

    it "#reoffer_agreement! returns a declined award to pending and re-funds it" do
      event = create(:event, cost_cents: 10_000)
      registration = create(:event_registration, event:)
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 5_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 5_000)
      scholarship.reload
      scholarship.decline_agreement!("No longer available")
      scholarship.update!(amount_cents: 6_000) # adjust terms first, still declined

      scholarship.reoffer_agreement!

      expect(scholarship.agreement_pending?).to be(true)
      expect(scholarship.allocation.reload.amount).to eq(6_000)
      expect(scholarship.latest_agreement_response).to have_attributes(status: "pending", responder: "admin")
    end

    it "excludes declined scholarships from the .not_declined scope" do
      active = create(:scholarship)
      declined = create(:scholarship)
      declined.decline_agreement!("out")

      expect(Scholarship.not_declined).to include(active)
      expect(Scholarship.not_declined).not_to include(declined)
    end

    it "accepting a declined award reinstates it and re-funds the allocation" do
      event = create(:event, cost_cents: 10_000)
      registration = create(:event_registration, event:)
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 5_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 5_000)
      scholarship.reload
      scholarship.decline_agreement!("no")
      expect(scholarship.allocation.reload.amount).to eq(0)

      # The admin "Accepted" toggle routes through agreement_signed=.
      scholarship.update!(agreement_signed: true)

      expect(scholarship.agreement_signed?).to be(true)
      expect(scholarship.agreement_declined?).to be(false)
      expect(scholarship.allocation.reload.amount).to eq(5_000)
    end
  end

  describe "requesting additional support" do
    it "#request_additional_support! records the status, contribution, reason, and time" do
      scholarship = create(:scholarship)

      scholarship.request_additional_support!(contribution_cents: 12_000, reason: "Employer can help")

      expect(scholarship.agreement_support_requested?).to be(true)
      response = scholarship.latest_agreement_response
      expect(response).to have_attributes(status: "support_requested", contribution_cents: 12_000,
                                          reason: "Employer can help", responder: "recipient")
      expect(response.responded_at).to be_present
    end

    it "keeps the award live — not declined, allocation untouched, still in .not_declined" do
      event = create(:event, cost_cents: 10_000)
      registration = create(:event_registration, event:)
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 5_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 5_000)
      scholarship.reload

      scholarship.request_additional_support!(contribution_cents: 2_000)

      expect(scholarship.agreement_declined?).to be(false)
      expect(scholarship.allocation.reload.amount).to eq(5_000)
      expect(Scholarship.not_declined).to include(scholarship)
    end

    it "reactivates to pending (re-offering) when the admin changes the amount" do
      event = create(:event, cost_cents: 10_000)
      registration = create(:event_registration, event:)
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 5_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 5_000)
      scholarship.reload
      scholarship.request_additional_support!(contribution_cents: 2_000)

      scholarship.update!(amount_cents: 7_000)

      expect(scholarship.reload.agreement_pending?).to be(true)
      expect(scholarship.allocation.reload.amount).to eq(7_000)
      expect(scholarship.latest_agreement_response).to have_attributes(status: "pending", responder: "admin")
    end

    it "stays support-requested when an edit doesn't touch the amount" do
      scholarship = create(:scholarship, amount_cents: 5_000)
      scholarship.request_additional_support!(contribution_cents: 2_000)

      scholarship.update!(tasks_completed: true)

      expect(scholarship.reload.agreement_support_requested?).to be(true)
    end
  end

  describe "agreement response history" do
    it "appends a row on each transition, capturing status, reason, responder, and amount" do
      scholarship = create(:scholarship, amount_cents: 5_000)

      scholarship.decline_agreement!("Not this year", by: "recipient")
      scholarship.reoffer_agreement!(by: "admin")
      scholarship.accept_agreement!(by: "recipient")

      history = scholarship.agreement_responses.chronological
      expect(history.map(&:status)).to eq(%w[declined pending accepted])
      expect(history.first).to have_attributes(reason: "Not this year", responder: "recipient", amount_cents: 5_000)
      expect(history.last).to have_attributes(status: "accepted", responder: "recipient")
    end
  end

  describe "report filter scopes" do
    let(:event) { create(:event, cost_cents: 50_000) }
    let(:funder) { create(:organization, name: "Community Trust") }
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }

    let!(:from_funder) do
      reg = create(:event_registration, event: event, registrant: person1, status: "attended")
      scholarship = create(:scholarship, recipient: person1, amount_cents: 4_000, grant: create(:grant, funder: funder))
      create(:allocation, source: scholarship, allocatable: reg, amount: 4_000)
      scholarship
    end

    let!(:other) do
      reg = create(:event_registration, event: create(:event, cost_cents: 50_000), registrant: person2, status: "attended")
      scholarship = create(:scholarship, recipient: person2, amount_cents: 2_000, grant: create(:grant))
      create(:allocation, source: scholarship, allocatable: reg, amount: 2_000)
      scholarship
    end

    it ".from_funder returns only scholarships whose grant that funder gave" do
      expect(Scholarship.from_funder(funder)).to contain_exactly(from_funder)
    end

    it ".for_events returns only scholarships awarded at the given events" do
      expect(Scholarship.for_events([ event.id ])).to contain_exactly(from_funder)
    end

    it ".event_ids returns the events the scholarships were awarded at" do
      expect(Scholarship.from_funder(funder).event_ids).to contain_exactly(event.id)
    end
  end

  describe "timeline" do
    it "labels itself with the recipient" do
      scholarship = create(:scholarship)
      expect(scholarship.timeline_label).to eq("Scholarship: #{scholarship.recipient.name}")
    end

    it "labels itself without a recipient" do
      scholarship = build(:scholarship, recipient: nil)
      expect(scholarship.timeline_label).to eq("Scholarship")
    end
  end
end
