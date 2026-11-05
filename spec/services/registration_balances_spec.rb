require "rails_helper"

RSpec.describe RegistrationBalances do
  let(:paid_event) { create(:event, cost_cents: 10_000) }
  let(:pricier_event) { create(:event, cost_cents: 25_000) }

  def pay(registration, cents)
    create(:allocation, source: create(:payment, amount_cents: cents, amount_cents_remaining: cents),
                        allocatable: registration, amount: cents)
  end

  def due_cents(registration)
    described_class.new([ registration.id ]).due_cents_by_id[registration.id]
  end

  it "owes the event's cost less what's allocated" do
    registration = create(:event_registration, event: paid_event, status: "registered")
    pay(registration, 4_000)

    expect(due_cents(registration)).to eq(6_000)
  end

  it "floors an over-allocated registration at zero" do
    registration = create(:event_registration, event: create(:event, cost_cents: 1_000), status: "registered")
    pay(registration, 1_000)
    registration.event.update!(cost_cents: 500)

    expect(due_cents(registration)).to eq(0)
  end

  it "reads nothing owed for a free event" do
    registration = create(:event_registration, event: create(:event, cost_cents: nil), status: "registered")

    expect(due_cents(registration)).to eq(0)
  end

  it "reads 0 for a registration it wasn't asked about" do
    expect(described_class.new([]).due_cents_by_id[123]).to eq(0)
  end

  context "with a transfer" do
    let(:source) { create(:event_registration, event: paid_event, status: "transferred_out") }
    let(:incoming) do
      create(:event_registration, event: pricier_event, registrant: source.registrant, status: "registered",
        transferred_from_registration: source)
    end

    it "prices it at the source event and settles it with money on both regs" do
      pay(source, 6_000)
      pay(incoming, 1_000)

      expect(due_cents(incoming)).to eq(3_000)
    end

    it "follows a double transfer back to the first event" do
      pay(source, 2_000)
      pay(incoming, 3_000)
      incoming.update!(status: "transferred_out")
      latest = create(:event_registration, event: create(:event, cost_cents: 50_000), registrant: source.registrant,
        status: "registered", transferred_from_registration: incoming)
      pay(latest, 1_000)

      expect(due_cents(latest)).to eq(4_000)
    end

    it "doesn't add a source reg it wasn't asked about" do
      expect(described_class.new([ incoming.id ]).due_cents_by_id.keys).to eq([ incoming.id ])
    end
  end
end
