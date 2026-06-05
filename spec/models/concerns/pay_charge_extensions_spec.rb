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

    before do
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

    it "is idempotent" do
      pay_charge.update!(object: refunded_object, amount_refunded: 15_00)
      expect(Refund.count).to eq(1)
    end
  end
end
