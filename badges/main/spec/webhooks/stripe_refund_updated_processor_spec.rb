require "rails_helper"

RSpec.describe StripeRefundUpdatedProcessor do
  subject(:processor) { described_class.new }

  let(:person) { create(:person) }
  let(:external_payment) do
    ExternalProcessorPayment.create!(
      stripe_charge_id: "ch_test_123",
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

  let(:charge_hash) do
    {
      "id" => "ch_test_123",
      "amount" => 30_00,
      "amount_refunded" => 0,
      "refunded" => false,
      "refunds" => { "object" => "list", "data" => [], "has_more" => false }
    }
  end

  let(:retrieved_charge) do
    instance_double(Stripe::Charge, to_hash: charge_hash)
  end

  let(:stripe_refund) do
    double(
      "Stripe::Refund",
      object: "refund",
      id: "re_test_refund",
      status: "canceled",
      amount: 15_00,
      charge: "ch_test_123"
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
    before do
      allow(Stripe::Charge).to receive(:retrieve).and_return(retrieved_charge)
    end

    it "destroys the local Refund record" do
      expect { processor.call(event) }.to change(Refund, :count).by(-1)
    end

    it "reverses the amount_cents_remaining via after_destroy callback" do
      expect { processor.call(event) }
        .to change { external_payment.reload.amount_cents_remaining }
        .from(0).to(15_00)
    end

    it "refreshes the stripe_charge metadata after canceling" do
      processor.call(event)
      expect(external_payment.reload.metadata["stripe_charge"]).to include(
        "amount_refunded" => 0,
        "refunds" => hash_including("data" => [])
      )
    end

    it "is idempotent on replay" do
      processor.call(event)
      expect { processor.call(event) }.not_to change(Refund, :count)
    end
  end
end
