require "rails_helper"

RSpec.describe StripeRefundUpdatedProcessor do
  subject(:processor) { described_class.new }

  let(:person) { create(:person) }
  let(:external_payment) do
    ExternalProcessorPayment.create!(
      person: person,
      amount_cents: 30_00,
      amount_cents_remaining: 15_00,
      currency: "usd",
      skip_pay_charge_validation: true,
      metadata: { stripe_charge_id: "ch_test_123" }
    )
  end

  let!(:refund) do
    Refund.create!(
      refundable: external_payment,
      recipient: person,
      amount_cents: 15_00,
      method: "stripe",
      stripe_refund_id: "re_test_refund"
    )
  end

  let(:stripe_refund) do
    double(
      "Stripe::Refund",
      object: "refund",
      id: "re_test_refund",
      status: "canceled",
      amount: 15_00
    )
  end

  let(:event) { double("Stripe::Event", data: double("data", object: stripe_refund)) }

  describe "early returns" do
    it "does nothing when the object is not a refund" do
      allow(stripe_refund).to receive(:object).and_return("charge")

      expect { processor.call(event) }.not_to change(Refund, :count)
    end

    it "does nothing when status is not canceled" do
      allow(stripe_refund).to receive(:status).and_return("succeeded")

      expect { processor.call(event) }.not_to change(Refund, :count)
    end

    it "does nothing when no local Refund matches" do
      allow(stripe_refund).to receive(:id).and_return("re_unknown")

      expect { processor.call(event) }.not_to change(Refund, :count)
    end
  end

  describe "refund cancellation" do
    it "destroys the local Refund record" do
      expect { processor.call(event) }.to change(Refund, :count).by(-1)
    end

    it "reverses the amount_cents_remaining via after_destroy callback" do
      expect { processor.call(event) }
        .to change { external_payment.reload.amount_cents_remaining }
        .from(0).to(15_00)
    end

    it "is idempotent on replay" do
      processor.call(event)
      expect { processor.call(event) }.not_to change(Refund, :count)
    end
  end
end
