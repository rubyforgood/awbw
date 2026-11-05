require "rails_helper"

RSpec.describe EventRevenueFigures do
  # One event carrying every money shape the report reads: payments, a funded and
  # an unfunded scholarship, a registration discount, paid / partly paid / unpaid
  # CE, a comped CE fee, and a cancelled registration whose money must be ignored.
  let(:event) { create(:event, cost_cents: 10_000) }
  let(:person1) { create(:person) }
  let(:person2) { create(:person) }

  let!(:reg1) { create(:event_registration, event: event, registrant: person1, status: "registered") }
  let!(:reg2) { create(:event_registration, event: event, registrant: person2, status: "registered") }

  before do
    create(:allocation, source: create(:payment, amount_cents: 6_000, amount_cents_remaining: 6_000),
                        allocatable: reg1, amount: 6_000)
    funded = create(:scholarship, recipient: person1, amount_cents: 4_000, grant: create(:grant))
    create(:allocation, source: funded, allocatable: reg1, amount: 4_000)

    create(:allocation, source: create(:payment, amount_cents: 3_000, amount_cents_remaining: 3_000),
                        allocatable: reg2, amount: 3_000)
    unfunded = create(:scholarship, recipient: person2, amount_cents: 2_000, grant: nil)
    create(:allocation, source: unfunded, allocatable: reg2, amount: 2_000)
    create(:allocation, source: create(:discount, amount_cents: 1_000), allocatable: reg2, amount: 1_000)

    ce_paid = create(:continuing_education_registration, event_registration: reg1, cost_cents: 7_500)
    create(:allocation, source: create(:payment, amount_cents: 7_500, amount_cents_remaining: 7_500),
                        allocatable: ce_paid, amount: 7_500)
    ce_partial = create(:continuing_education_registration, event_registration: reg2, cost_cents: 6_000)
    create(:allocation, source: create(:payment, amount_cents: 2_000, amount_cents_remaining: 2_000),
                        allocatable: ce_partial, amount: 2_000)

    cancelled = create(:event_registration, event: event, registrant: create(:person), status: "cancelled")
    create(:continuing_education_registration, event_registration: cancelled, cost_cents: 12_000)
    create(:allocation, source: create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000),
                        allocatable: cancelled, amount: 5_000)
  end

  subject(:figures) { described_class.new([ event ]).for(event) }

  it "reports each money component for the event" do
    expect(figures.registration_payments_cents).to eq(9_000)
    expect(figures.registration_outstanding_cents).to eq(4_000)
    expect(figures.funded_scholarship_cents).to eq(4_000)
    expect(figures.unfunded_scholarship_cents).to eq(2_000)
    expect(figures.discount_cents).to eq(1_000)
    expect(figures.ce_paid_cents).to eq(9_500)
    expect(figures.ce_outstanding_cents).to eq(4_000)
  end

  # The report and a single event's dashboard must never disagree, so the batched
  # figures are held against the per-event service they replaced.
  it "matches the event's dashboard" do
    dashboard = EventDashboard.new(event)

    expect(figures.registration_payments_cents).to eq(dashboard.received_cents)
    expect(figures.registration_outstanding_cents).to eq(dashboard.outstanding_cents)
    expect(figures.funded_scholarship_cents).to eq(dashboard.funded_scholarship_cents)
    expect(figures.unfunded_scholarship_cents).to eq(dashboard.unfunded_scholarship_cents)
    expect(figures.ce_paid_cents).to eq(dashboard.cont_ed_paid_cents)
    expect(figures.ce_outstanding_cents).to eq(dashboard.cont_ed_outstanding_cents)
  end

  describe "a transfer's money (#2947)" do
    let(:old_event) { create(:event, cost_cents: 8_000) }
    let(:person) { create(:person) }
    let!(:out_reg) { create(:event_registration, event: old_event, registrant: person, status: "transferred_out") }
    let!(:in_reg) do
      create(:event_registration, event: event, registrant: person, status: "registered",
        transferred_from_registration: out_reg)
    end
    let(:loader) { described_class.new([ old_event, event ]) }

    before do
      create(:allocation, source: create(:payment, amount_cents: 3_000, amount_cents_remaining: 3_000),
                          allocatable: out_reg, amount: 3_000)
      create(:allocation, source: create(:payment, amount_cents: 1_000, amount_cents_remaining: 1_000),
                          allocatable: in_reg, amount: 1_000)
      create(:allocation, source: create(:discount, amount_cents: 500), allocatable: out_reg, amount: 500)
      award = create(:scholarship, recipient: person, amount_cents: 1_500, grant: create(:grant))
      create(:allocation, source: award, allocatable: out_reg, amount: 1_500)
      ce = create(:continuing_education_registration, event_registration: in_reg, cost_cents: 2_000)
      create(:allocation, source: create(:payment, amount_cents: 700, amount_cents_remaining: 700),
                          allocatable: ce, amount: 700)
    end

    it "counts the old reg's money at the old event" do
      old_figures = loader.for(old_event)

      expect(old_figures.registration_payments_cents).to eq(3_000)
      expect(old_figures.discount_cents).to eq(500)
      expect(old_figures.funded_scholarship_cents).to eq(1_500)
      expect(old_figures.registration_outstanding_cents).to eq(0)
    end

    it "counts the new reg's money and the balance left at the new event" do
      new_figures = loader.for(event)

      expect(new_figures.registration_payments_cents).to eq(9_000 + 1_000)
      expect(new_figures.registration_outstanding_cents).to eq(4_000 + 2_000)
      expect(new_figures.ce_paid_cents).to eq(9_500 + 700)
    end

    it "agrees with both events' dashboards" do
      [ old_event, event ].each do |report_event|
        row = loader.for(report_event)
        dashboard = EventDashboard.new(report_event)

        expect(row.registration_payments_cents).to eq(dashboard.received_cents)
        expect(row.registration_outstanding_cents).to eq(dashboard.outstanding_cents)
        expect(row.funded_scholarship_cents).to eq(dashboard.funded_scholarship_cents)
        expect(row.ce_paid_cents).to eq(dashboard.cont_ed_paid_cents)
        expect(row.ce_outstanding_cents).to eq(dashboard.cont_ed_outstanding_cents)
      end
    end

    it "names them in each event's drilldown beside the money there" do
      old_breakdown = loader.breakdown_for(old_event)
      new_breakdown = loader.breakdown_for(event)

      expect(old_breakdown.registration_payments.find { |c| c.person == person }.cents).to eq(3_000)
      expect(old_breakdown.registration_outstanding.map(&:person)).not_to include(person)
      expect(new_breakdown.registration_payments.find { |c| c.person == person }.cents).to eq(1_000)
      expect(new_breakdown.registration_outstanding.find { |c| c.person == person }.cents).to eq(2_000)
    end
  end

  it "leaves CE unpaid past its payment deadline out of what's owed, keeping its cash" do
    event.update!(ce_payment_due_deadline: 1.day.ago)

    expect(figures.ce_paid_cents).to eq(9_500)
    expect(figures.ce_outstanding_cents).to eq(0)
    expect(figures.ce_outstanding_cents).to eq(EventDashboard.new(event).cont_ed_outstanding_cents)
  end

  it "counts a comped CE fee as a discount" do
    ce = create(:continuing_education_registration, event_registration: reg2, cost_cents: 5_000)
    create(:allocation, source: create(:discount, amount_cents: 5_000), allocatable: ce, amount: 5_000)

    expect(figures.discount_cents).to eq(6_000)
    expect(figures.ce_outstanding_cents).to eq(4_000)
  end

  it "returns zeros for an event with no registrations" do
    other = create(:event, cost_cents: 10_000)

    expect(described_class.new([ event, other ]).for(other)).to eq(described_class::EMPTY)
  end

  describe "#breakdown_for" do
    subject(:breakdown) { described_class.new([ event ]).breakdown_for(event) }

    def amounts(contributors)
      contributors.to_h { |contributor| [ contributor.person, contributor.cents ] }
    end

    it "names the registrants (and recipients) behind each component with their amounts" do
      expect(amounts(breakdown.registration_payments)).to eq(person1 => 6_000, person2 => 3_000)
      expect(amounts(breakdown.registration_outstanding)).to eq(person2 => 4_000)
      expect(amounts(breakdown.funded_scholarships)).to eq(person1 => 4_000)
      expect(amounts(breakdown.unfunded_scholarships)).to eq(person2 => 2_000)
      expect(amounts(breakdown.discounts)).to eq(person2 => 1_000)
      expect(amounts(breakdown.ce_paid)).to eq(person1 => 7_500, person2 => 2_000)
      expect(amounts(breakdown.ce_outstanding)).to eq(person2 => 4_000)
    end

    it "reconciles each drilldown list with its subtotal" do
      totals = described_class.new([ event ]).for(event)

      expect(breakdown.registration_payments.sum(&:cents)).to eq(totals.registration_payments_cents)
      expect(breakdown.registration_outstanding.sum(&:cents)).to eq(totals.registration_outstanding_cents)
      expect(breakdown.funded_scholarships.sum(&:cents)).to eq(totals.funded_scholarship_cents)
      expect(breakdown.unfunded_scholarships.sum(&:cents)).to eq(totals.unfunded_scholarship_cents)
      expect(breakdown.discounts.sum(&:cents)).to eq(totals.discount_cents)
      expect(breakdown.ce_paid.sum(&:cents)).to eq(totals.ce_paid_cents)
      expect(breakdown.ce_outstanding.sum(&:cents)).to eq(totals.ce_outstanding_cents)
    end

    it "omits people with a zero share and excludes cancelled registrants" do
      cancelled_person = EventRegistration.find_by(status: "cancelled")&.registrant
      expect(breakdown.registration_payments.map(&:person)).not_to include(cancelled_person)
      expect(breakdown.registration_outstanding.map(&:person)).not_to include(person1)
    end

    it "sorts contributors by name" do
      names = breakdown.registration_payments.map { |contributor| contributor.person.name }
      expect(names).to eq(names.sort_by(&:downcase))
    end

    it "returns an empty breakdown for an event with no registrations" do
      other = create(:event, cost_cents: 10_000)
      expect(described_class.new([ event, other ]).breakdown_for(other)).to eq(described_class::EMPTY_BREAKDOWN)
    end
  end

  it "loads every event in a fixed number of queries" do
    events = [ event ] + Array.new(3) do
      other = create(:event, cost_cents: 5_000)
      registration = create(:event_registration, event: other, registrant: create(:person), status: "registered")
      create(:continuing_education_registration, event_registration: registration, cost_cents: 1_000)
      other
    end

    # The Setting row is read once per request and memoized on Current, so warm it
    # here rather than letting the count depend on whether setup happened to read it.
    Setting.current

    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      loader = described_class.new(events)
      events.each { |e| loader.for(e) }
    end

    # 6 batch component queries (incl. which CE still counts) + 2 for what's owed
    # (RegistrationBalances) + 2 constant queries that classify AWBW-donated grants
    # as subsidy (the AWBW org lookup and its grant ids), regardless of how many
    # events are loaded.
    expect(queries).to eq(10)
  end
end
