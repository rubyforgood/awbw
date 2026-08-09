require "rails_helper"

RSpec.describe EventScholarshipFigures do
  let(:event) { create(:event, cost_cents: 10_000) }
  let(:person1) { create(:person) }
  let(:person2) { create(:person) }
  let(:person3) { create(:person) }

  let!(:reg1) { create(:event_registration, event: event, registrant: person1, status: "attended") }
  let!(:reg2) { create(:event_registration, event: event, registrant: person2, status: "attended") }

  before do
    funded = create(:scholarship, recipient: person1, amount_cents: 4_000, grant: create(:grant))
    create(:allocation, source: funded, allocatable: reg1, amount: 4_000)

    unfunded = create(:scholarship, recipient: person2, amount_cents: 2_000, grant: nil)
    create(:allocation, source: unfunded, allocatable: reg2, amount: 2_000)

    # A scholarship on a cancelled registration must be ignored (inactive).
    cancelled = create(:event_registration, event: event, registrant: person3, status: "cancelled")
    ignored = create(:scholarship, recipient: person3, amount_cents: 9_000, grant: create(:grant))
    create(:allocation, source: ignored, allocatable: cancelled, amount: 9_000)
  end

  subject(:figures) { described_class.new([ event ]).for(event) }

  it "splits scholarship dollars and counts into funded vs unfunded" do
    expect(figures.funded_cents).to eq(4_000)
    expect(figures.unfunded_cents).to eq(2_000)
    expect(figures.funded_count).to eq(1)
    expect(figures.unfunded_count).to eq(1)
    expect(figures.scholarship_cents).to eq(6_000)
    expect(figures.scholarship_count).to eq(2)
  end

  it "counts attended registrations (cancelled excluded)" do
    expect(figures.attended_count).to eq(2)
  end

  it "counts an AWBW self-donated grant as unfunded, matching the dashboard" do
    awbw = create(:organization, name: "A Window Between Worlds")
    reg = create(:event_registration, event: event, registrant: create(:person), status: "attended")
    subsidy = create(:scholarship, recipient: reg.registrant, amount_cents: 1_000, grant: create(:grant, donor: awbw))
    create(:allocation, source: subsidy, allocatable: reg, amount: 1_000)

    figures = described_class.new([ event ]).for(event)
    expect(figures.funded_cents).to eq(4_000)
    expect(figures.unfunded_cents).to eq(3_000)
    expect(figures.unfunded_count).to eq(2)
  end

  describe "funder narrowing" do
    it "counts only scholarships drawn from the given funder's grants" do
      funder = create(:organization, name: "Community Trust")
      reg = create(:event_registration, event: event, registrant: create(:person), status: "attended")
      award = create(:scholarship, recipient: reg.registrant, amount_cents: 5_000, grant: create(:grant, donor: funder))
      create(:allocation, source: award, allocatable: reg, amount: 5_000)

      figures = described_class.new([ event ], funder: funder).for(event)
      expect(figures.funded_cents).to eq(5_000)
      expect(figures.unfunded_cents).to eq(0)
      expect(figures.scholarship_count).to eq(1)
    end

    it "counts nothing for a funder who gave no grants" do
      funder = create(:organization, name: "Empty Fund")
      figures = described_class.new([ event ], funder: funder).for(event)
      expect(figures.scholarship_cents).to eq(0)
      expect(figures.scholarship_count).to eq(0)
    end
  end

  # The report and a single event's dashboard must never disagree.
  it "matches the event's dashboard" do
    dashboard = EventDashboard.new(event)

    expect(figures.funded_cents).to eq(dashboard.funded_scholarship_cents)
    expect(figures.unfunded_cents).to eq(dashboard.unfunded_scholarship_cents)
    expect(figures.funded_count).to eq(dashboard.funded_scholarship_count)
    expect(figures.unfunded_count).to eq(dashboard.unfunded_scholarship_count)
    expect(figures.attended_count).to eq(dashboard.attendance_count_for("attended"))
  end

  it "returns zeros for an event with no registrations" do
    other = create(:event, cost_cents: 10_000)
    expect(described_class.new([ event, other ]).for(other)).to eq(described_class::EMPTY)
  end

  it "loads every event in a fixed number of queries" do
    events = [ event ] + Array.new(3) do
      other = create(:event)
      reg = create(:event_registration, event: other, registrant: create(:person), status: "attended")
      award = create(:scholarship, recipient: reg.registrant, amount_cents: 1_000, grant: create(:grant))
      create(:allocation, source: award, allocatable: reg, amount: 1_000)
      other
    end

    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      loader = described_class.new(events)
      events.each { |e| loader.for(e) }
    end

    # 3 batch component queries + 2 constant queries classifying AWBW-donated
    # grants as subsidy (the org lookup + its grant ids), independent of event count.
    expect(queries).to eq(5)
  end
end
