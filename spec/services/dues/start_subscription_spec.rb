require "rails_helper"

RSpec.describe Dues::StartSubscription do
  let(:person) { create(:person) }

  it "creates a subscription with a comped first year" do
    subscription = described_class.call(person: person)

    expect(subscription.person).to eq(person)
    expect(subscription.rate_cents).to be_nil
    expect(subscription).not_to be_cancelled

    term = subscription.dues_registrations.sole
    expect(term.cost_cents).to eq(0)
    expect(term).to be_paid_in_full
    expect(term.start_date).to eq(Date.current)
    expect(term.end_date).to eq(Date.current + 1.year - 1.day)
  end

  it "leaves the person dues current straight away" do
    described_class.call(person: person)
    expect(person.reload).to be_dues_current
  end

  it "does nothing the second time" do
    described_class.call(person: person)

    expect { described_class.call(person: person) }.not_to change(DuesSubscription, :count)
    expect(person.dues_registrations.count).to eq(1)
  end

  it "does nothing when the person already has a cancelled subscription" do
    create(:dues_subscription, :cancelled, person: person)

    expect { described_class.call(person: person) }.not_to change(DuesSubscription, :count)
  end

  it "does nothing without a person" do
    expect { described_class.call(person: nil) }.not_to change(DuesSubscription, :count)
  end
end
