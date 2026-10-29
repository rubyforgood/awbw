require "rails_helper"

RSpec.describe Membership::InvoiceCheckout do
  let(:invoice) { create(:membership_invoice, cost_cents: 2_500) }
  let(:fake_session) { double(id: "cs_test_123", url: "https://checkout.stripe.com/membership", status: "open") }
  let(:processor) { instance_double("Pay::Stripe::Customer") }
  let(:success_url) { "https://example.test/payment/success" }
  let(:cancel_url) { "https://example.test/payment/cancelled" }

  before do
    allow_any_instance_of(Person).to receive(:stripe_payment_processor).and_return(processor)
    allow_any_instance_of(Person).to receive(:stripe_customer).and_return(nil)
    allow(processor).to receive(:checkout).and_return(fake_session)
  end

  def checkout
    described_class.call(invoice:, success_url:, cancel_url:)
  end

  it "claims the invoice, creates a checkout session, and stores its id" do
    result = checkout

    expect(result).to be_success
    expect(result.session).to eq(fake_session)
    expect(invoice.reload).to be_payment_in_progress
    expect(invoice.checkout_session_id).to eq("cs_test_123")
    expect(processor).to have_received(:checkout).with(
      hash_including(
        mode: "payment",
        metadata: { membership_id: invoice.membership_id, membership_invoice_id: invoice.id },
        success_url:,
        cancel_url:
      )
    )
  end

  it "asks Stripe to save the card when requested" do
    result = described_class.call(invoice:, success_url:, cancel_url:, save_card: true)

    expect(result).to be_success
    expect(processor).to have_received(:checkout).with(
      hash_including(
        payment_intent_data: {
          metadata: { membership_id: invoice.membership_id, membership_invoice_id: invoice.id },
          setup_future_usage: "off_session"
        }
      )
    )
  end

  it "resumes an open session without creating another" do
    invoice.update_columns(payment_in_progress_at: 5.minutes.ago, checkout_session_id: "cs_open")
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .with("cs_open")
      .and_return(fake_session)

    result = checkout

    expect(result).to be_success
    expect(result.session).to eq(fake_session)
    expect(processor).not_to have_received(:checkout)
  end

  it "does not resume an open session when the card must be saved" do
    invoice.update_columns(payment_in_progress_at: 5.minutes.ago, checkout_session_id: "cs_open")
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .with("cs_open")
      .and_return(fake_session)

    result = described_class.call(invoice:, success_url:, cancel_url:, save_card: true)

    expect(result).not_to be_success
    expect(result.errors).to include(Membership::InvoiceCheckout::IN_PROGRESS_ERROR)
    expect(invoice.reload.checkout_session_id).to eq("cs_open")
    expect(processor).not_to have_received(:checkout)
  end

  it "does not create a second session while a payment is in progress without a session id" do
    invoice.update_column(:payment_in_progress_at, 5.minutes.ago)
    timestamp = invoice.reload.payment_in_progress_at

    result = checkout

    expect(result).not_to be_success
    expect(result.errors).to include(Membership::InvoiceCheckout::IN_PROGRESS_ERROR)
    expect(invoice.reload.payment_in_progress_at).to be_within(1.second).of(timestamp)
    expect(processor).not_to have_received(:checkout)
  end

  it "refuses while an autopay attempt is pending" do
    invoice.charge_attempts.create!(
      attempt_number: 1,
      status: "pending",
      amount_cents: 100,
      attempted_at: 5.minutes.ago
    )

    result = checkout

    expect(result).not_to be_success
    expect(result.errors).to include(Membership::InvoiceCheckout::IN_PROGRESS_ERROR)
    expect(processor).not_to have_received(:checkout)
  end

  it "refuses while a stale pending attempt is still unresolved" do
    invoice.charge_attempts.create!(
      attempt_number: 1,
      status: "pending",
      amount_cents: 100,
      attempted_at: 2.hours.ago
    )

    result = checkout

    expect(result).not_to be_success
    expect(result.errors).to include(Membership::InvoiceCheckout::IN_PROGRESS_ERROR)
    expect(processor).not_to have_received(:checkout)
  end

  %w[unknown needs_action].each do |status|
    it "refuses while an autopay attempt is #{status}" do
      invoice.charge_attempts.create!(
        attempt_number: 1,
        status: status,
        amount_cents: 100,
        attempted_at: 2.hours.ago
      )

      result = checkout

      expect(result).not_to be_success
      expect(result.errors).to include(Membership::InvoiceCheckout::IN_PROGRESS_ERROR)
      expect(processor).not_to have_received(:checkout)
    end
  end

  it "allows a new checkout after a failed autopay attempt" do
    invoice.charge_attempts.create!(
      attempt_number: 1,
      status: "failed",
      amount_cents: 100,
      attempted_at: 2.hours.ago
    )

    result = checkout

    expect(result).to be_success
    expect(processor).to have_received(:checkout).once
  end

  it "reclaims a lock that is older than the checkout window" do
    invoice.update_column(:payment_in_progress_at, 32.minutes.ago)

    result = checkout

    expect(result).to be_success
    expect(invoice.reload).to be_payment_in_progress
    expect(invoice.checkout_session_id).to eq("cs_test_123")
    expect(processor).to have_received(:checkout).once
  end

  it "creates a new session when the stored session has expired" do
    invoice.update_columns(payment_in_progress_at: 5.minutes.ago, checkout_session_id: "cs_expired")
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .with("cs_expired")
      .and_return(double(status: "expired"))

    result = checkout

    expect(result).to be_success
    expect(invoice.reload.checkout_session_id).to eq("cs_test_123")
    expect(processor).to have_received(:checkout).once
  end

  it "does not create a new session when the stored session is complete" do
    invoice.update_columns(payment_in_progress_at: 5.minutes.ago, checkout_session_id: "cs_complete")
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .with("cs_complete")
      .and_return(double(status: "complete"))

    result = checkout

    expect(result).not_to be_success
    expect(result.errors).to include(Membership::InvoiceCheckout::COMPLETED_ERROR)
    expect(invoice.reload.checkout_session_id).to eq("cs_complete")
    expect(processor).not_to have_received(:checkout)
  end

  it "replaces a session that Stripe no longer knows about" do
    invoice.update_columns(payment_in_progress_at: 5.minutes.ago, checkout_session_id: "cs_missing")
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .with("cs_missing")
      .and_raise(Stripe::InvalidRequestError.new("No such checkout session", nil))

    result = checkout

    expect(result).to be_success
    expect(invoice.reload.checkout_session_id).to eq("cs_test_123")
    expect(processor).to have_received(:checkout).once
  end

  it "clears the lock if Stripe fails after this call claimed it" do
    allow(processor).to receive(:checkout).and_raise(Stripe::StripeError.new("Stripe is down"))

    expect { checkout }.to raise_error(Stripe::StripeError, "Stripe is down")
    expect(invoice.reload).not_to be_payment_in_progress
    expect(invoice.checkout_session_id).to be_nil
  end

  describe ".cancel" do
    before do
      invoice.update_columns(payment_in_progress_at: Time.current, checkout_session_id: "cs_cancel")
    end

    it "expires an open session and clears the lock" do
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .with("cs_cancel")
        .and_return(double(status: "open"))
      allow(Stripe::Checkout::Session).to receive(:expire)
        .with("cs_cancel")
        .and_return(double(status: "expired"))

      result = described_class.cancel(invoice:)

      expect(result).to be_success
      expect(invoice.reload).not_to be_payment_in_progress
      expect(invoice.checkout_session_id).to be_nil
    end

    it "clears an already-expired session without expiring it again" do
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .with("cs_cancel")
        .and_return(double(status: "expired"))
      allow(Stripe::Checkout::Session).to receive(:expire)

      result = described_class.cancel(invoice:)

      expect(result).to be_success
      expect(Stripe::Checkout::Session).not_to have_received(:expire)
      expect(invoice.reload.checkout_session_id).to be_nil
    end

    it "leaves a completed session locked" do
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .with("cs_cancel")
        .and_return(double(status: "complete"))

      result = described_class.cancel(invoice:)

      expect(result).not_to be_success
      expect(invoice.reload.checkout_session_id).to eq("cs_cancel")
      expect(invoice).to be_payment_in_progress
    end

    it "clears the lock if the session expires before it can be expired" do
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .with("cs_cancel")
        .and_return(double(status: "open"), double(status: "expired"))
      allow(Stripe::Checkout::Session).to receive(:expire)
        .and_raise(Stripe::InvalidRequestError.new("Session is expired", nil))

      result = described_class.cancel(invoice:)

      expect(result).to be_success
      expect(invoice.reload.checkout_session_id).to be_nil
      expect(invoice).not_to be_payment_in_progress
    end

    it "does not clear the lock if the session completes before it can be expired" do
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .with("cs_cancel")
        .and_return(double(status: "open"), double(status: "complete"))
      allow(Stripe::Checkout::Session).to receive(:expire)
        .and_raise(Stripe::InvalidRequestError.new("Session is complete", nil))

      result = described_class.cancel(invoice:)

      expect(result).not_to be_success
      expect(invoice.reload.checkout_session_id).to eq("cs_cancel")
      expect(invoice).to be_payment_in_progress
    end

    it "does not clear a newer checkout session" do
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .with("cs_old")
        .and_return(double(status: "expired"))

      result = described_class.cancel(invoice:, session_id: "cs_old")

      expect(result).not_to be_success
      expect(invoice.reload.checkout_session_id).to eq("cs_cancel")
      expect(invoice).to be_payment_in_progress
    end

    it "leaves the lock when Stripe cannot be reached" do
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .and_raise(Stripe::StripeError.new("Stripe is down"))

      result = described_class.cancel(invoice:)

      expect(result).not_to be_success
      expect(invoice.reload).to be_payment_in_progress
      expect(invoice.checkout_session_id).to eq("cs_cancel")
    end
  end
end
