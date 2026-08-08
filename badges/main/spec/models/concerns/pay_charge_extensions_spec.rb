# spec/models/concerns/pay_charge_extensions_spec.rb
require "rails_helper"

RSpec.describe PayChargeExtensions do
  let(:user) { create(:user) }
  let(:person) { create(:person, user: user) }
  let(:event) { create(:event, cost_cents: 15_00) }
  let(:registration) { create(:event_registration, registrant: person, event: event) }

  let(:pay_customer) do
    Pay::Customer.create!(owner: user, processor: :stripe, processor_id: "cus_test")
  end

  let(:charge_object) do
    {
      "id" => "ch_123",
      "object" => "charge",
      "amount" => 30_00,
      "currency" => "usd",
      "paid" => true,
      "metadata" => { "event_registration_id" => registration.id },
      "refunds" => { "object" => "list", "data" => [], "has_more" => false }
    }
  end

  let!(:pay_charge) do
    Pay::Charge.create!(
      customer: pay_customer,
      processor_id: "ch_123",
      amount: 30_00,
      amount_refunded: 0,
      currency: "usd",
      object: charge_object,
      metadata: { "event_registration_id" => registration.id }
    )
  end

  describe "charge creation" do
    it "creates an ExternalProcessorPayment" do
      payment = ExternalProcessorPayment.last
      expect(payment).to have_attributes(
        amount_cents: 30_00,
        person: person,
        pay_charge: pay_charge
      )
    end

    it "creates an Allocation for the remaining cost" do
      expect(Allocation.count).to eq(1)
      allocation = Allocation.last
      expect(allocation.source).to eq(ExternalProcessorPayment.last)
      expect(allocation.allocatable).to eq(registration)
      expect(allocation.amount).to eq(15_00)
    end

    it "adjusts amount_cents_remaining after allocation" do
      expect(ExternalProcessorPayment.last.amount_cents_remaining).to eq(15_00)
    end
  end

  describe "CE payment via ce_registration_id metadata" do
    let(:ce_registration) do
      create(:continuing_education_registration, event_registration: registration, cost_cents: 15_00)
    end

    let(:charge_object) do
      {
        "id" => "ch_ce_456",
        "object" => "charge",
        "amount" => 10_00,
        "currency" => "usd",
        "paid" => true,
        "metadata" => { "ce_registration_id" => ce_registration.id, "event_registration_id" => registration.id },
        "refunds" => { "object" => "list", "data" => [], "has_more" => false }
      }
    end

    let!(:pay_charge) do
      Pay::Charge.create!(
        customer: pay_customer,
        processor_id: "ch_ce_456",
        amount: 10_00,
        amount_refunded: 0,
        currency: "usd",
        object: charge_object,
        metadata: { "ce_registration_id" => ce_registration.id, "event_registration_id" => registration.id }
      )
    end

    it "creates an ExternalProcessorPayment" do
      payment = ExternalProcessorPayment.find_by(pay_charge_id: pay_charge.id)
      expect(payment).to have_attributes(
        amount_cents: 10_00,
        person: person,
        pay_charge: pay_charge
      )
    end

    it "creates an Allocation against the CE registration" do
      payment = ExternalProcessorPayment.find_by(pay_charge_id: pay_charge.id)
      allocation = payment.allocations.first
      expect(allocation.allocatable).to eq(ce_registration)
      expect(allocation.amount).to eq(10_00)
    end

    it "allocates against the CE registration even when event_registration_id is also present" do
      payment = ExternalProcessorPayment.find_by(pay_charge_id: pay_charge.id)
      expect(payment.allocations.first.allocatable).to eq(ce_registration)
      expect(Allocation.where(allocatable: registration, source: payment)).to be_empty
    end

    it "is idempotent" do
      expect do
        pay_charge.update!(object: charge_object)
      end.not_to change(ExternalProcessorPayment, :count)
    end
  end

  describe "refund sync" do
    let(:refunded_object) do
      charge_object.deep_merge(
        "amount_refunded" => 15_00,
        "refunds" => {
          "data" => [
            { "id" => "re_123", "object" => "refund", "amount" => 15_00, "currency" => "usd", "status" => "succeeded" }
          ]
        }
      )
    end

    let(:retrieved_charge) do
      instance_double(Stripe::Charge, to_hash: refunded_object)
    end

    before do
      allow(Stripe::Charge).to receive(:retrieve).and_return(retrieved_charge)
      pay_charge.update!(object: refunded_object, amount_refunded: 15_00)
    end

    it "creates a Refund record" do
      expect(Refund.count).to eq(1)
      refund = Refund.last
      expect(refund).to have_attributes(
        refundable: ExternalProcessorPayment.last,
        recipient: person,
        amount_cents: 15_00,
        method: "stripe",
        stripe_refund_id: "re_123"
      )
    end

    it "adjusts amount_cents_remaining correctly" do
      expect(ExternalProcessorPayment.last.amount_cents_remaining).to eq(0)
    end

    it "refreshes the stripe_charge metadata with the updated refund state" do
      payment = ExternalProcessorPayment.last
      expect(payment.metadata["stripe_charge"]).to include(
        "amount_refunded" => 15_00,
        "refunds" => hash_including("data" => array_including(hash_including("id" => "re_123")))
      )
    end

    it "is idempotent" do
      pay_charge.update!(object: refunded_object, amount_refunded: 15_00)
      expect(Refund.count).to eq(1)
    end
  end
  describe "membership subscription charges" do
    let(:member) { create(:person) }
    let(:membership) { create(:membership, person: member) }

    def renewal_charge(period_start:, amount: Membership::ANNUAL_COST_CENTS, charge_id: "ch_membership")
      pay_subscription = Pay::Subscription.create!(
        customer: pay_customer, name: "default", processor_id: "sub_membership",
        processor_plan: "membership", status: "active", quantity: 1,
        current_period_start: period_start,
        metadata: { "membership_id" => membership.id }
      )

      Pay::Charge.create!(
        customer: pay_customer, subscription: pay_subscription, processor_id: charge_id,
        amount: amount, amount_refunded: 0, currency: "usd", metadata: {},
        object: { "id" => charge_id, "amount" => amount, "currency" => "usd", "paid" => true,
                  "metadata" => {}, "refunds" => { "data" => [], "has_more" => false } }
      )
    end

    it "allocates the charge to the year covering the invoice period" do
      invoice = create(:membership_invoice, membership: membership,
        cost_cents: Membership::ANNUAL_COST_CENTS,
        start_date: Date.current, end_date: Date.current + 1.year - 1.day)

      renewal_charge(period_start: Date.current.to_time)

      expect(invoice.reload).to be_paid_in_full
      expect(invoice.allocations.sole.amount).to eq(Membership::ANNUAL_COST_CENTS)
    end

    it "records the payment against the subscription's person, not the Stripe customer owner" do
      create(:membership_invoice, membership: membership,
        start_date: Date.current, end_date: Date.current + 1.year - 1.day)

      renewal_charge(period_start: Date.current.to_time)

      expect(ExternalProcessorPayment.find_by(stripe_charge_id: "ch_membership").person).to eq(member)
    end

    it "creates the year when the renewal arrives before the nightly job made one" do
      next_period = Date.current + 2.years

      expect { renewal_charge(period_start: next_period.to_time) }
        .to change { membership.membership_invoices.count }.by(1)

      expect(membership.membership_invoices.last.start_date).to eq(next_period)
    end

    it "never allocates more than the year still owes" do
      invoice = create(:membership_invoice, membership: membership,
        cost_cents: 1_000, start_date: Date.current, end_date: Date.current + 1.year - 1.day)

      renewal_charge(period_start: Date.current.to_time, amount: Membership::ANNUAL_COST_CENTS)

      expect(invoice.allocations.sole.amount).to eq(1_000)
      expect(ExternalProcessorPayment.find_by(stripe_charge_id: "ch_membership").amount_cents_remaining)
        .to eq(Membership::ANNUAL_COST_CENTS - 1_000)
    end

    it "leaves a subscription charge that is not a membership unallocated" do
      create(:membership_invoice, membership: membership,
        start_date: Date.current, end_date: Date.current + 1.year - 1.day)
      other = Pay::Subscription.create!(
        customer: pay_customer, name: "default", processor_id: "sub_other",
        processor_plan: "other", status: "active", quantity: 1, metadata: {}
      )

      expect {
        Pay::Charge.create!(
          customer: pay_customer, subscription: other, processor_id: "ch_other",
          amount: 2_500, amount_refunded: 0, currency: "usd", metadata: {},
          object: { "id" => "ch_other", "amount" => 2_500, "currency" => "usd", "paid" => true,
                    "metadata" => {}, "refunds" => { "data" => [], "has_more" => false } }
        )
      }.not_to change { Allocation.count }
    end

    it "allocates a checkout charge from the invoice metadata before Pay links the subscription" do
      invoice = create(:membership_invoice, membership: membership,
        cost_cents: Membership::ANNUAL_COST_CENTS,
        start_date: Date.current, end_date: Date.current + 1.year - 1.day)

      period_start = Date.current.to_time.to_i
      Pay::Charge.create!(
        customer: pay_customer, processor_id: "ch_checkout",
        amount: Membership::ANNUAL_COST_CENTS, amount_refunded: 0, currency: "usd",
        metadata: {},
        data: {
          "stripe_invoice" => {
            "period_start" => period_start,
            "parent" => {
              "type" => "subscription_details",
              "subscription_details" => { "metadata" => { "membership_id" => membership.id.to_s } }
            }
          }
        },
        object: { "id" => "ch_checkout", "amount" => Membership::ANNUAL_COST_CENTS,
                  "currency" => "usd", "paid" => true, "metadata" => {},
                  "refunds" => { "data" => [], "has_more" => false } }
      )

      expect(invoice.reload).to be_paid_in_full
      expect(invoice.allocations.sole.amount).to eq(Membership::ANNUAL_COST_CENTS)
      expect(ExternalProcessorPayment.find_by(stripe_charge_id: "ch_checkout"))
        .to have_attributes(external_origin: false, person: member)
    end
  end
end
