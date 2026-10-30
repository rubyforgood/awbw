require "rails_helper"

RSpec.describe "Membership invoice reconciliation", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }
  let(:attempt) do
    invoice.charge_attempts.create!(attempt_number: 1, status: "pending",
      amount_cents: 1_000, attempted_at: 1.hour.ago)
  end

  before { sign_in admin }

  def manual_payment
    customer = Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_manual", default: true)
    pay_charge = create(:pay_charge, customer:, processor_id: "ch_manual", amount: 1_000)
    create(:external_processor_payment, person:, amount_cents: 1_000,
      amount_cents_remaining: 1_000, stripe_charge_id: "ch_manual", pay_charge:)
    intent = Stripe::PaymentIntent.construct_from(
      id: "pi_manual", object: "payment_intent", status: "succeeded", amount: 1_000,
      currency: "usd", customer: customer.processor_id,
      metadata: { "membership_invoice_id" => invoice.id.to_s }
    )
    allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(intent)
    allow(Pay::Stripe::Charge).to receive(:sync_payment_intent).and_return(pay_charge)
    pay_charge
  end

  it "marks a no-intent attempt failed" do
    post membership_invoice_reconciliation_path(invoice,
      operation: "fail_attempt", attempt_id: attempt.id)

    expect(response).to redirect_to(membership_invoice_reconciliation_path(invoice))
    expect(flash[:notice]).to match(/Marked attempt/)
    expect(attempt.reload).to be_failed
  end

  it "cancels a needs_action attempt" do
    attempt.update!(status: "needs_action", payment_intent_id: "pi_test")
    allow(Membership::Reconcile::CancelIntent).to receive(:call).and_return(
      Membership::Reconcile::CancelIntent::Result.new(
        status: :canceled, attempt:, message: "Canceled the payment attempt.", errors: []
      )
    )

    delete membership_invoice_reconciliation_path(invoice, attempt_id: attempt.id)

    expect(response).to redirect_to(membership_invoice_reconciliation_path(invoice))
    expect(flash[:notice]).to match(/Canceled/)
  end

  it "clears a stale checkout session" do
    invoice.update_columns(checkout_session_id: "cs_test", payment_in_progress_at: 2.hours.ago)
    expect(MembershipInvoice.needing_reconciliation).to include(invoice)

    post membership_invoice_reconciliation_path(invoice, operation: "clear_checkout")

    expect(response).to redirect_to(membership_invoice_reconciliation_path(invoice))
    expect(flash[:notice]).to match(/Cleared the stale checkout/)
    expect(invoice.reload.checkout_session_id).to be_nil
    expect(MembershipInvoice.needing_reconciliation).not_to include(invoice)
  end

  it "refuses to clear a checkout that is still in progress" do
    invoice.update_columns(checkout_session_id: "cs_test", payment_in_progress_at: Time.current)

    post membership_invoice_reconciliation_path(invoice, operation: "clear_checkout")

    expect(response).to redirect_to(membership_invoice_reconciliation_path(invoice))
    expect(flash[:alert]).to match(/still in progress/)
    expect(invoice.reload.checkout_session_id).to eq("cs_test")
  end

  it "denies a member" do
    sign_out admin
    sign_in create(:user, person:)

    post membership_invoice_reconciliation_path(invoice,
      operation: "fail_attempt", attempt_id: attempt.id)

    expect(response).to redirect_to(root_path)
    expect(attempt.reload).not_to be_failed
  end

  it "renders the Stripe lookup page for an admin" do
    allow(Membership::Reconcile::Lookup).to receive(:call).and_return(
      Membership::Reconcile::Lookup::Result.new(
        candidates: [], local_payments: [],
        message: "No Stripe payments found for this invoice.", errors: []
      )
    )

    get membership_invoice_reconciliation_path(invoice)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Reconcile payments")
    expect(response.body).to include("Manual PaymentIntent")
    expect(response.body).to include("Use this PaymentIntent")
    expect(response.body).to include("Record this charge")
    expect(response.body).to include("No Stripe payments found for this invoice")
  end

  it "clears a missing PaymentIntent and fails the attempt" do
    attempt.update!(status: "unknown", payment_intent_id: "pi_missing")
    allow(Pay::Payment).to receive(:from_id)
      .and_raise(Stripe::InvalidRequestError.new("No such payment_intent", nil))

    post membership_invoice_reconciliation_path(invoice,
      operation: "clear_missing_intent", attempt_id: attempt.id)

    expect(response).to redirect_to(membership_invoice_reconciliation_path(invoice))
    expect(flash[:notice]).to match(/Cleared the missing PaymentIntent/)
    expect(attempt.reload).to be_failed
    expect(attempt.payment_intent_id).to be_nil
  end

  it "applies a manually entered PaymentIntent and resolves the attempt" do
    pay_charge = manual_payment
    post membership_invoice_reconciliation_path(invoice,
      operation: "use_intent", payment_intent_id: "pi_manual", attempt_id: attempt.id)

    expect(response).to redirect_to(membership_invoice_reconciliation_path(invoice))
    expect(flash[:notice]).to match(/Applied/)
    expect(attempt.reload).to have_attributes(status: "succeeded", pay_charge:)
    expect(invoice.reload).to be_paid_in_full
  end

  it "refuses to apply a payment while a checkout is in progress" do
    payment = create(:external_processor_payment, person:, amount_cents: 1_000,
      amount_cents_remaining: 1_000, metadata: { "membership_invoice_id" => invoice.id })
    invoice.update_columns(payment_in_progress_at: Time.current)

    post membership_invoice_reconciliation_path(invoice,
      operation: "apply_payment", payment_id: payment.id)

    expect(response).to redirect_to(membership_invoice_reconciliation_path(invoice))
    expect(flash[:alert]).to match(/already in progress/)
    expect(invoice.reload).not_to be_paid_in_full
    expect(payment.reload.amount_cents_remaining).to eq(1_000)
  end

  it "records a manual charge when no local payment exists" do
    charge = Stripe::Charge.construct_from(id: "ch_manual", object: "charge", amount: 1_000,
      currency: "usd", metadata: {})
    intent = Stripe::PaymentIntent.construct_from(
      id: "pi_manual", object: "payment_intent", status: "succeeded", amount: 1_000,
      currency: "usd", customer: "cus_test", latest_charge: charge,
      metadata: { "membership_invoice_id" => invoice.id.to_s }
    )
    attempt.update!(status: "unknown", payment_intent_id: "pi_manual")
    allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(intent)
    allow(Pay::Stripe::Charge).to receive(:sync_payment_intent)
      .and_raise(Stripe::APIConnectionError.new("Pay is down"))

    post membership_invoice_reconciliation_path(invoice,
      operation: "record_charge", payment_intent_id: "pi_manual", attempt_id: attempt.id)

    expect(response).to redirect_to(membership_invoice_reconciliation_path(invoice))
    expect(flash[:notice]).to match(/Applied/)
    expect(ExternalProcessorPayment.find_by(stripe_charge_id: "ch_manual")).to be_present
    expect(invoice.reload).to be_paid_in_full
    expect(attempt.reload).to be_succeeded
  end

  it "reports an invalid manual PaymentIntent id" do
    allow(Stripe::PaymentIntent).to receive(:retrieve)
      .and_raise(Stripe::InvalidRequestError.new("No such payment_intent", nil))

    post membership_invoice_reconciliation_path(invoice,
      operation: "use_intent", payment_intent_id: "pi_missing")

    expect(response).to redirect_to(membership_invoice_reconciliation_path(invoice))
    expect(flash[:alert]).to match(/Could not retrieve/)
  end
end
