require "rails_helper"

RSpec.describe Membership::Autopay::Charge do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person: person, cost_cents: 10_000) }
  let(:invoice) do
    create(:membership_invoice, membership: membership, cost_cents: 10_000,
      start_date: Date.current, end_date: Date.current + 1.year - 1.day)
  end
  let(:customer) do
    Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}", default: true)
  end

  let!(:card) do
    Pay::Stripe::PaymentMethod.create!(customer: customer,
      processor_id: "pm_#{SecureRandom.hex(4)}",
      payment_method_type: "card",
      data: { "brand" => "visa", "last4" => "4242" })
  end

  let(:pay_charge) do
    create(:pay_charge, customer: customer, processor_id: "ch_test", amount: invoice.cost_cents)
  end

  before do
    # Simulate what PayChargeExtensions does inside Pay::Stripe::Charge.sync:
    # the payment record and its allocation to the invoice.
    allow(Pay::Stripe::Charge).to receive(:sync) do
      payment = ExternalProcessorPayment.create!(
        stripe_charge_id: pay_charge.processor_id,
        external_origin: false,
        person: person,
        amount_cents: invoice.cost_cents,
        amount_cents_remaining: invoice.cost_cents,
        currency: "usd",
        pay_charge: pay_charge
      )
      Allocation.create!(source: payment, allocatable: invoice, amount: invoice.cost_cents)
      pay_charge
    end
  end

  def intent(status:, latest_charge: nil, last_payment_error: nil, id: "pi_#{SecureRandom.hex(4)}")
    Stripe::PaymentIntent.construct_from(
      id: id,
      object: "payment_intent",
      status: status,
      amount: invoice.remaining_cost,
      currency: "usd",
      latest_charge: latest_charge,
      last_payment_error: last_payment_error
    )
  end

  def stub_intent(**attributes)
    value = intent(**attributes)
    allow_any_instance_of(Pay::Stripe::Customer).to receive(:create_payment_intent).and_return(value)
    value
  end

  def charge_object(id: "ch_#{SecureRandom.hex(4)}")
    Stripe::Charge.construct_from(id: id, object: "charge", amount: invoice.remaining_cost,
      currency: "usd", paid: true)
  end

  def latest_attempt
    invoice.charge_attempts.recent.first
  end

  describe "#call" do
    it "records a succeeded charge through Pay" do
      charge = charge_object(id: "ch_test")
      value = stub_intent(status: "succeeded", latest_charge: charge)

      result = described_class.call(invoice: invoice)

      expect(result).to be_success
      expect(Pay::Stripe::Charge).to have_received(:sync)
        .with("ch_test", object: charge, stripe_account: nil)
      expect(latest_attempt).to have_attributes(
        status: "succeeded",
        payment_intent_id: value.id,
        pay_charge: pay_charge
      )
    end

    it "marks the attempt unknown when Pay cannot link the charge" do
      allow(Pay::Stripe::Charge).to receive(:sync).and_return(nil)
      stub_intent(status: "succeeded", latest_charge: charge_object)

      result = described_class.call(invoice: invoice)

      expect(result).not_to be_success
      expect(latest_attempt).to have_attributes(status: "unknown", error_code: "sync_missing")
    end

    it "leaves a succeeded charge unresolved when it was not applied to the invoice" do
      allow(Pay::Stripe::Charge).to receive(:sync).and_return(pay_charge)
      stub_intent(status: "succeeded", latest_charge: charge_object(id: "ch_test"))

      result = described_class.call(invoice: invoice)

      expect(result).not_to be_success
      expect(latest_attempt).to have_attributes(status: "unknown", error_code: "allocation_failed")
    end

    it "leaves a succeeded charge unresolved when its payment has no allocation" do
      ExternalProcessorPayment.create!(
        stripe_charge_id: pay_charge.processor_id,
        external_origin: false,
        person: person,
        amount_cents: invoice.cost_cents,
        amount_cents_remaining: invoice.cost_cents,
        currency: "usd",
        pay_charge: pay_charge
      )
      allow(Pay::Stripe::Charge).to receive(:sync).and_return(pay_charge)
      stub_intent(status: "succeeded", latest_charge: charge_object(id: "ch_test"))

      result = described_class.call(invoice: invoice)

      expect(result).not_to be_success
      expect(latest_attempt).to have_attributes(status: "unknown", error_code: "allocation_failed")
    end

    it "leaves a succeeded charge unresolved when another payment settled the invoice" do
      allow(Pay::Stripe::Charge).to receive(:sync) do
        other_payment = create(:payment, amount_cents: invoice.cost_cents)
        create(:allocation, source: other_payment, allocatable: invoice, amount: invoice.cost_cents)
        pay_charge
      end
      stub_intent(status: "succeeded", latest_charge: charge_object(id: "ch_test"))

      result = described_class.call(invoice: invoice)

      expect(result).not_to be_success
      expect(latest_attempt).to have_attributes(status: "unknown", error_code: "allocation_failed")
    end

    it "leaves a succeeded charge unresolved when Pay cannot record it" do
      allow(Pay::Stripe::Charge).to receive(:sync).and_raise(StandardError, "Stripe is down")
      stub_intent(status: "succeeded", latest_charge: charge_object)

      result = described_class.call(invoice: invoice)

      expect(result).not_to be_success
      expect(latest_attempt).to have_attributes(status: "unknown", error_code: "sync_failed")
    end

    it "marks the attempt unknown when Stripe reports success without a charge" do
      stub_intent(status: "succeeded", latest_charge: nil)

      result = described_class.call(invoice: invoice)

      expect(result).not_to be_success
      expect(Pay::Stripe::Charge).not_to have_received(:sync)
      expect(latest_attempt).to have_attributes(status: "unknown", error_code: "missing_charge")
    end

    it "records authentication-required charges as needs_action" do
      value = stub_intent(status: "requires_action")

      result = described_class.call(invoice: invoice)

      expect(result).not_to be_success
      expect(latest_attempt).to have_attributes(
        status: "needs_action",
        payment_intent_id: value.id,
        error_code: "authentication_required"
      )
    end

    it "records declines as failed with Stripe's reason" do
      stub_intent(status: "requires_payment_method",
        last_payment_error: { code: "card_declined", message: "Your card was declined." })

      result = described_class.call(invoice: invoice)

      expect(result).not_to be_success
      expect(latest_attempt).to have_attributes(
        status: "failed",
        error_code: "card_declined",
        error_message: "Your card was declined."
      )
      expect(latest_attempt.next_attempt_on).to eq(Date.current + 1.day)
    end

    it "charges an invoice issued before its start date" do
      invoice.update_columns(start_date: Date.current + 1.day,
        end_date: Date.current + 1.year)
      stub_intent(status: "succeeded", latest_charge: charge_object)

      result = described_class.call(invoice: invoice)

      expect(result).to be_success
    end

    it "refuses to charge an invoice outside the automatic payment window" do
      start_date = Date.current + Membership.renewal_window_days + 1.day
      invoice.update_columns(start_date:, end_date: start_date + 1.year)

      result = described_class.call(invoice: invoice)

      expect(result.errors).to include("This invoice is outside the automatic payment window.")
      expect(invoice.charge_attempts).to be_empty
    end

    it "refuses while an autopay attempt is already pending" do
      invoice.charge_attempts.create!(
        attempt_number: 1,
        status: "pending",
        amount_cents: invoice.remaining_cost,
        attempted_at: 5.minutes.ago
      )

      result = described_class.call(invoice: invoice)

      expect(result.errors).to include("A payment is already in progress for this invoice.")
      expect(invoice.charge_attempts.count).to eq(1)
    end
  end

  describe ".reconcile" do
    it "runs an unresolved attempt through the same state machine" do
      charge = charge_object(id: "ch_test")
      value = intent(id: "pi_reconcile", status: "succeeded", latest_charge: charge)
      attempt = invoice.charge_attempts.create!(
        attempt_number: 1, status: "unknown", amount_cents: invoice.remaining_cost,
        attempted_at: 1.hour.ago, payment_intent_id: value.id
      )
      allow(Pay::Payment).to receive(:from_id)
        .with(value.id, stripe_account: nil)
        .and_return(Pay::Payment.new(value))

      result = described_class.reconcile(attempt)

      expect(result).to be_success
      expect(Pay::Stripe::Charge).to have_received(:sync)
        .with("ch_test", object: charge, stripe_account: nil)
      expect(attempt.reload).to have_attributes(status: "succeeded", pay_charge: pay_charge)
    end

    it "fetches a charge the reconciled intent only references by id" do
      value = intent(id: "pi_reconcile", status: "succeeded", latest_charge: "ch_test")
      attempt = invoice.charge_attempts.create!(
        attempt_number: 1, status: "unknown", amount_cents: invoice.remaining_cost,
        attempted_at: 1.hour.ago, payment_intent_id: value.id
      )
      charge = charge_object(id: "ch_test")
      allow(Pay::Payment).to receive(:from_id).and_return(Pay::Payment.new(value))
      allow(Stripe::Charge).to receive(:retrieve).and_return(charge)

      result = described_class.reconcile(attempt)

      expect(result).to be_success
      expect(Stripe::Charge).to have_received(:retrieve)
        .with({ id: "ch_test", expand: Pay::Stripe::Charge::EXPAND }, {})
      expect(attempt.reload).to have_attributes(status: "succeeded", pay_charge: pay_charge)
    end

    it "does nothing without a PaymentIntent to look up" do
      attempt = invoice.charge_attempts.create!(
        attempt_number: 1, status: "pending", amount_cents: invoice.remaining_cost,
        attempted_at: 1.hour.ago
      )

      result = described_class.reconcile(attempt)

      expect(result.errors).to include("This attempt has no PaymentIntent to reconcile.")
    end
  end
end
