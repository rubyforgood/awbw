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

    expect(response).to redirect_to(membership_invoice_path(invoice, anchor: "reconciliation"))
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

    expect(response).to redirect_to(membership_invoice_path(invoice, anchor: "reconciliation"))
    expect(flash[:notice]).to match(/Canceled/)
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

    get new_membership_invoice_reconciliation_path(invoice)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Reconcile payments")
    expect(response.body).to include("No Stripe payments found for this invoice")
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

    get new_membership_invoice_reconciliation_path(invoice)

    expect(response.body).to include("Use for attempt #1")
    expect(response.body).to include("Apply $10")
  end
end
