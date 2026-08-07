require "rails_helper"

RSpec.describe Membership::Start do
  let(:person) { create(:person) }

  it "creates a subscription with a comped first year" do
    subscription = described_class.call(person: person)

    expect(subscription.person).to eq(person)
    expect(subscription.cost_cents).to be_nil
    expect(subscription).not_to be_cancelled

    invoice = subscription.membership_invoices.sole
    expect(invoice.cost_cents).to eq(0)
    expect(invoice).to be_paid_in_full
    expect(invoice.start_date).to eq(Date.current)
    expect(invoice.end_date).to eq(Date.current + 1.year - 1.day)
  end

  it "leaves the person membership current straight away" do
    described_class.call(person: person)
    expect(person.reload).to be_membership_current
  end

  it "does nothing the second time" do
    described_class.call(person: person)

    expect { described_class.call(person: person) }.not_to change(Membership, :count)
    expect(person.membership_invoices.count).to eq(1)
  end

  it "does nothing when the person already has a cancelled subscription" do
    create(:membership, :cancelled, person: person)

    expect { described_class.call(person: person) }.not_to change(Membership, :count)
  end

  it "does nothing without a person" do
    expect { described_class.call(person: nil) }.not_to change(Membership, :count)
  end
end
