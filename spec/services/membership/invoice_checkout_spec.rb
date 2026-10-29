require "rails_helper"

RSpec.describe Membership::InvoiceCheckout do
  let(:invoice) { create(:membership_invoice, cost_cents: 2_500) }
  let(:fake_session) { double(url: "https://checkout.stripe.com/membership") }
  let(:processor) { instance_double("Pay::Stripe::Customer") }
  let(:success_url) { "https://example.test/payment/success" }
  let(:cancel_url) { "https://example.test/payment/cancelled" }

  before do
    allow_any_instance_of(Person).to receive(:set_payment_processor)
    allow_any_instance_of(Person).to receive(:payment_processor).and_return(processor)
    allow(processor).to receive(:checkout).and_return(fake_session)
  end

  def checkout
    described_class.call(invoice:, success_url:, cancel_url:)
  end

  it "claims the invoice and creates a checkout session" do
    expect(checkout).to eq(fake_session)
    expect(invoice.reload).to be_payment_in_progress
    expect(processor).to have_received(:checkout).with(
      hash_including(
        mode: "payment",
        metadata: { membership_id: invoice.membership_id, membership_invoice_id: invoice.id },
        success_url:,
        cancel_url:
      )
    )
  end

  it "does not create a second session while the invoice is already in progress" do
    checkout

    expect(checkout).to be_nil
    expect(processor).to have_received(:checkout).once
    expect(invoice.reload).to be_payment_in_progress
  end

  it "does not clear a lock owned by another request" do
    invoice.update_column(:payment_in_progress_at, 5.minutes.ago)
    timestamp = invoice.reload.payment_in_progress_at

    expect(checkout).to be_nil
    expect(invoice.reload.payment_in_progress_at).to be_within(1.second).of(timestamp)
    expect(processor).not_to have_received(:checkout)
  end

  it "reclaims a lock that is older than the checkout window" do
    invoice.update_column(:payment_in_progress_at, 61.minutes.ago)

    expect(checkout).to eq(fake_session)
    expect(invoice.reload).to be_payment_in_progress
    expect(processor).to have_received(:checkout).once
  end

  it "clears the lock if Stripe fails after this call claimed it" do
    allow(processor).to receive(:checkout).and_raise(Stripe::StripeError.new("Stripe is down"))

    expect { checkout }.to raise_error(Stripe::StripeError, "Stripe is down")
    expect(invoice.reload).not_to be_payment_in_progress
  end
end
