# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::ReconcileDefaultPayCustomer do
  let(:person) { create(:person) }

  def customer(processor_id:, default: true, processor: "stripe")
    Pay::Customer.create!(owner: person, processor: processor, processor_id: processor_id, default: default)
  end

  it "prefers the requested customer even when another is default" do
    own = customer(processor_id: "cus_own")
    other = customer(processor_id: "cus_other")

    described_class.new(person, preferred_customer_id: own.id).call

    expect(own.reload.default).to be true
    expect(other.reload.deleted_at).to be_present
  end

  it "soft-deletes the redundant loser without destroying its charges" do
    winner = customer(processor_id: "cus_keep")
    loser = customer(processor_id: "cus_drop")
    charge = create(:pay_charge, customer: loser)

    described_class.new(person, preferred_customer_id: winner.id).call

    expect(loser.reload.deleted_at).to be_present
    expect(loser.default).to be false
    expect(winner.reload.default).to be true
    expect(person.pay_customers.active).to contain_exactly(winner)
    expect(charge.reload.customer_id).to eq(loser.id)
  end

  it "falls back to the newest customer when no preferred id is present" do
    older = customer(processor_id: "cus_old")
    older.update!(created_at: 2.days.ago)
    newer = customer(processor_id: "cus_new")

    described_class.new(person, preferred_customer_id: nil).call

    expect(newer.reload.default).to be true
    expect(older.reload.deleted_at).to be_present
  end

  it "leaves a live customer of a different processor untouched" do
    winner = customer(processor_id: "cus_stripe")
    paypal = customer(processor_id: "cus_paypal", default: false, processor: "braintree")

    described_class.new(person, preferred_customer_id: winner.id).call

    expect(paypal.reload.deleted_at).to be_nil
    expect(winner.reload.default).to be true
  end

  it "is a no-op when only one live customer exists" do
    only = customer(processor_id: "cus_only")

    expect { described_class.new(person, preferred_customer_id: nil).call }
      .not_to change { only.reload.attributes.slice("default", "deleted_at") }
  end
end
