# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::ReconcileDefaultPayCustomer do
  let(:person) { create(:person) }

  def customer(processor_id:, default: true, processor: "stripe")
    Pay::Customer.create!(owner: person, processor: processor, processor_id: processor_id, default: default)
  end

  def active_subscription_for(customer)
    Pay::Subscription.create!(customer: customer, name: "default", processor_id: "sub_#{customer.processor_id}",
      processor_plan: "membership", status: "active", quantity: 1)
  end

  it "keeps the subscription-bearing customer default even when the survivor's own default is another" do
    own = customer(processor_id: "cus_own")
    subscribed = customer(processor_id: "cus_sub", default: false)
    active_subscription_for(subscribed)

    described_class.new(person, preferred_customer_id: own.id).call

    expect(subscribed.reload.default).to be true
    expect(own.reload.default).to be false
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

  it "never soft-deletes a customer with an active subscription, only clears its default" do
    winner = customer(processor_id: "cus_keep")
    active_subscription_for(winner)
    other_subscribed = customer(processor_id: "cus_other", default: false)
    active_subscription_for(other_subscribed)

    described_class.new(person, preferred_customer_id: winner.id).call

    expect(other_subscribed.reload.deleted_at).to be_nil
    expect(other_subscribed.default).to be false
    expect(person.pay_customers.active).to contain_exactly(winner, other_subscribed)
  end

  it "ignores a canceled subscription still in its grace period when picking the winner" do
    own = customer(processor_id: "cus_own")
    canceled = customer(processor_id: "cus_canceled", default: false)
    Pay::Subscription.create!(customer: canceled, name: "default", processor_id: "sub_canceled",
      processor_plan: "membership", status: "active", quantity: 1, ends_at: 1.month.from_now)

    described_class.new(person, preferred_customer_id: own.id).call

    expect(own.reload.default).to be true
    expect(canceled.reload.deleted_at).to be_present
  end

  it "falls back to the survivor's own default when no customer has a subscription" do
    own = customer(processor_id: "cus_own", default: false)
    other = customer(processor_id: "cus_other")

    described_class.new(person, preferred_customer_id: own.id).call

    expect(own.reload.default).to be true
    expect(other.reload.deleted_at).to be_present
  end

  it "falls back to the newest customer when neither a subscription nor the preferred id is present" do
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
