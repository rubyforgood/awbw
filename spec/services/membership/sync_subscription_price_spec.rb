require "rails_helper"

RSpec.describe Membership::SyncSubscriptionPrice do
  let(:membership) { create(:membership) }
  let(:subscription) do
    instance_double(Pay::Stripe::Subscription,
      processor_id: "sub_test",
      stripe_account: nil,
      active?: true,
      past_due?: false,
      canceled?: false,
      cancel_now!: true)
  end

  def stripe_subscription(unit_amount:, interval: "year")
    Stripe::Subscription.construct_from(
      id: "sub_test",
      items: {
        data: [ {
          id: "si_test",
          price: {
            unit_amount: unit_amount,
            currency: "usd",
            product: "prod_test",
            recurring: { interval: interval, interval_count: 1 }
          }
        } ]
      }
    )
  end

  def bill_next_year(cost_cents)
    create(:membership_invoice, membership: membership, cost_cents: cost_cents,
      start_date: Date.current + 1.year, end_date: Date.current + 2.years - 1.day)
  end

  before do
    allow(membership).to receive(:stripe_subscription).and_return(subscription)
    allow(Stripe::Subscription).to receive(:retrieve).and_return(stripe_subscription(unit_amount: 1_000))
    allow(Stripe::Subscription).to receive(:update).and_return(stripe_subscription(unit_amount: 2_500))
    allow(Pay::Stripe::Subscription).to receive(:sync)
  end

  it "raises the item price to the next year's invoice without prorating" do
    bill_next_year(2_500)

    described_class.call(membership: membership)

    expect(Stripe::Subscription).to have_received(:update).with(
      "sub_test",
      {
        items: [ {
          id: "si_test",
          price_data: {
            currency: "usd",
            product: "prod_test",
            unit_amount: 2_500,
            recurring: { interval: "year", interval_count: 1 }
          }
        } ],
        proration_behavior: "none",
        expand: [ "items.data.price" ]
      },
      {}
    )
  end

  it "lowers the price too" do
    allow(Stripe::Subscription).to receive(:retrieve).and_return(stripe_subscription(unit_amount: 4_000))
    bill_next_year(2_500)

    described_class.call(membership: membership)

    expect(Stripe::Subscription).to have_received(:update)
  end

  it "refreshes Pay's copy of the subscription after the update" do
    bill_next_year(2_500)

    described_class.call(membership: membership)

    expect(Pay::Stripe::Subscription).to have_received(:sync).with("sub_test", object: an_instance_of(Stripe::Subscription))
  end

  it "leaves the price alone when it already matches" do
    bill_next_year(1_000)

    described_class.call(membership: membership)

    expect(Stripe::Subscription).not_to have_received(:update)
  end

  it "cancels the subscription when the next year is comped" do
    bill_next_year(0)

    described_class.call(membership: membership)

    expect(subscription).to have_received(:cancel_now!)
    expect(Stripe::Subscription).not_to have_received(:update)
  end

  it "does nothing without a subscription" do
    allow(membership).to receive(:stripe_subscription).and_return(nil)
    bill_next_year(2_500)

    described_class.call(membership: membership)

    expect(Stripe::Subscription).not_to have_received(:retrieve)
  end

  it "still syncs a past-due subscription, which will keep billing once it recovers" do
    allow(subscription).to receive(:active?).and_return(false)
    allow(subscription).to receive(:past_due?).and_return(true)
    bill_next_year(2_500)

    described_class.call(membership: membership)

    expect(Stripe::Subscription).to have_received(:update)
  end

  it "leaves a subscription already scheduled to cancel alone" do
    allow(subscription).to receive(:canceled?).and_return(true)
    bill_next_year(2_500)

    described_class.call(membership: membership)

    expect(Stripe::Subscription).not_to have_received(:update)
    expect(subscription).not_to have_received(:cancel_now!)
  end

  it "logs and swallows a Stripe error" do
    bill_next_year(2_500)
    allow(Stripe::Subscription).to receive(:update).and_raise(Stripe::StripeError.new("boom"))
    allow(Rails.logger).to receive(:warn)

    expect { described_class.call(membership: membership) }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with(/Could not sync the Stripe price/)
  end

  it "does nothing while memberships are disabled" do
    allow(Membership).to receive(:enabled?).and_return(false)
    bill_next_year(2_500)

    described_class.call(membership: membership)

    expect(Stripe::Subscription).not_to have_received(:retrieve)
  end
end
