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

  it "shows the reconciliation card on the membership" do
    attempt

    get membership_path(membership)

    expect(response.body).to include("Payment reconciliation")
    expect(response.body).to include(
      membership_invoice_reconciliation_path(invoice, return_to: "membership")
    )
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
    expect(response.body).to include("No Stripe payments found for this invoice")
  end

  it "shows local unallocated payments when Stripe can't be reached" do
    customer = Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test", default: true)
    charge = Pay::Charge.create!(
      customer:, processor_id: "ch_test", amount: 1_000, amount_refunded: 0,
      currency: "usd", metadata: {},
      object: { "paid" => false, "refunds" => { "object" => "list", "data" => [] } }
    )
    invoice.charge_attempts.create!(attempt_number: 2, status: "unknown",
      amount_cents: 1_000, attempted_at: 1.hour.ago, pay_charge: charge)
    create(:external_processor_payment, person:, amount_cents: 1_000,
      amount_cents_remaining: 1_000, stripe_charge_id: "ch_test")
    allow(Stripe::PaymentIntent).to receive(:list)
      .and_raise(Stripe::APIConnectionError.new("Stripe is down"))

    get membership_invoice_reconciliation_path(invoice)

    expect(response.body).to include("Stripe is down")
    expect(response.body).to include("ch_test")
    expect(response.body).to include("Apply $10")
  end

  it "offers to link or apply a Stripe candidate" do
    payment = create(:external_processor_payment, person:, amount_cents: 1_000, amount_cents_remaining: 1_000,
      stripe_charge_id: "ch_test")
    candidate = Membership::Reconcile::Lookup::Candidate.new(
      payment_intent_id: "pi_test", status: "succeeded", amount_cents: 1_000, currency: "usd",
      created_at: Time.current, attempt_number: "1", charge_id: "ch_test",
      attempt:, payment:, allocated: false
    )
    allow(Membership::Reconcile::Lookup).to receive(:call).and_return(
      Membership::Reconcile::Lookup::Result.new(
        candidates: [ candidate ], local_payments: [], message: nil, errors: []
      )
    )

    get membership_invoice_reconciliation_path(invoice)

    expect(response.body).to include("Use for attempt #1")
    expect(response.body).to include("Apply $10")
  end
end
