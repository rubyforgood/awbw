require "rails_helper"

RSpec.describe StripeChargeRefundedProcessor do
  subject(:processor) { described_class.new }

  let(:person) { create(:person) }
  let(:external_payment) do
    ExternalProcessorPayment.create!(
      stripe_charge_id: "ch_test_123",
      person: person,
      amount_cents: 30_00,
      amount_cents_remaining: 30_00,
      currency: "usd",
      skip_pay_charge_validation: true
    )
  end

  let(:stripe_charge) do
    double(
      "Stripe::Charge",
      id: "ch_test_123",
      amount_refunded: 15_00
    )
  end

  let(:event) { double("Stripe::Event", data: double("data", object: stripe_charge)) }

  describe "early returns" do
    it "does nothing when amount_refunded is 0" do
      allow(stripe_charge).to receive(:amount_refunded).and_return(0)

      expect { processor.call(event) }.not_to change(Refund, :count)
    end

    it "does nothing when no ExternalProcessorPayment matches" do
      external_payment.update!(stripe_charge_id: "ch_other")

      expect { processor.call(event) }.not_to change(Refund, :count)
    end
  end

  describe "refund creation" do
    let(:retrieved_charge) do
      double(
        "Stripe::Charge",
        refunds: double("refunds", data: [
          double("refund", id: "re_1", status: "succeeded", amount: 10_00),
          double("refund", id: "re_2", status: "succeeded", amount: 5_00)
        ])
      )
    end

    before do
      external_payment # ensure it exists
      allow(Stripe::Charge).to receive(:retrieve).and_return(retrieved_charge)
    end

    it "creates Refund records for each succeeded refund" do
      expect { processor.call(event) }.to change(Refund, :count).by(2)
    end

    it "links refunds to the ExternalProcessorPayment" do
      processor.call(event)
      expect(Refund.all.map(&:refundable)).to all(eq(external_payment))
    end

    it "sets the recipient to the payment's payer" do
      processor.call(event)
      expect(Refund.all.map(&:recipient)).to all(eq(person))
    end

    it "sets method to 'stripe' and stores stripe_refund_id" do
      processor.call(event)
      refund = Refund.find_by(stripe_refund_id: "re_1")
      expect(refund).to have_attributes(method: "stripe", amount_cents: 10_00)
    end

    it "updates amount_cents_remaining via the Refund callback" do
      expect { processor.call(event) }
        .to change { external_payment.reload.amount_cents_remaining }
        .from(30_00).to(15_00)
    end

    it "skips refunds that are not succeeded" do
      succeeded = double("refund", id: "re_1", status: "succeeded", amount: 10_00)
      pending_refund = double("refund", id: "re_2", status: "pending", amount: 5_00)
      allow(retrieved_charge).to receive(:refunds)
        .and_return(double("refunds", data: [ succeeded, pending_refund ]))

      expect { processor.call(event) }.to change(Refund, :count).by(1)
    end

    it "is idempotent on replay" do
      processor.call(event)
      expect { processor.call(event) }.not_to change(Refund, :count)
    end
  end

  describe "without a pay_charge" do
    let(:retrieved_charge) do
      double(
        "Stripe::Charge",
        refunds: double("refunds", data: [
          double("refund", id: "re_no_pc", status: "succeeded", amount: 10_00)
        ])
      )
    end

    before do
      external_payment # ensure it exists
      allow(Stripe::Charge).to receive(:retrieve).and_return(retrieved_charge)
    end

    it "still creates Refund records" do
      expect { processor.call(event) }.to change(Refund, :count).by(1)
    end

    it "updates amount_cents_remaining" do
      expect { processor.call(event) }
        .to change { external_payment.reload.amount_cents_remaining }
        .from(30_00).to(20_00)
    end
  end
end
