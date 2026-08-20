require "rails_helper"

RSpec.describe StripeChargeSucceededProcessor do
  subject(:processor) { described_class.new }

  let(:person) { create(:person, email: "person@example.com") }
  let(:pay_charge) { create(:pay_charge) }
  let(:stripe_charge_id) { pay_charge.processor_id }

  let(:stripe_charge) do
    double(
      "Stripe::Charge",
      id: stripe_charge_id,
      paid: true,
      amount: 30_00,
      currency: "usd",
      metadata: {},
      billing_details: nil,
      receipt_email: nil,
      customer: nil,
      invoice: nil,
      to_hash: { "id" => stripe_charge_id, "amount" => 30_00 }
    )
  end

  let(:event) { double("Stripe::Event", data: double("data", object: stripe_charge)) }

  describe "early returns" do
    it "does nothing when charge is not paid" do
      allow(stripe_charge).to receive(:paid).and_return(false)

      expect { processor.call(event) }.not_to change(ExternalProcessorPayment, :count)
    end

    it "does nothing when an EPP already exists with the same stripe_charge_id" do
      stripe_charge_id = "ch_app_originated"
      allow(stripe_charge).to receive(:id).and_return(stripe_charge_id)

      ExternalProcessorPayment.create!(
        stripe_charge_id: stripe_charge_id,
        person: person,
        pay_charge: pay_charge,
        amount_cents: 30_00,
        currency: "usd"
      )

      expect { processor.call(event) }.not_to change(ExternalProcessorPayment, :count)
    end
  end

  describe "person resolution" do
    it "creates an EPP with the person from pay_charge.customer.owner" do
      pay_charge.customer.update!(owner: person)

      expect { processor.call(event) }.to change(ExternalProcessorPayment, :count).by(1)
      epp = ExternalProcessorPayment.last
      expect(epp.person).to eq(person)
      expect(epp.pay_charge).to eq(pay_charge)
    end

    it "resolves person from billing_details.email" do
      other_id = "ch_no_pc"
      allow(stripe_charge).to receive(:id).and_return(other_id)
      allow(stripe_charge).to receive(:billing_details)
        .and_return(double(email: person.email))

      expect { processor.call(event) }.to change(ExternalProcessorPayment, :count).by(1)
      expect(ExternalProcessorPayment.last.person).to eq(person)
    end

    it "resolves person from receipt_email" do
      other_id = "ch_no_pc"
      allow(stripe_charge).to receive(:id).and_return(other_id)
      allow(stripe_charge).to receive(:receipt_email).and_return(person.email)

      expect { processor.call(event) }.to change(ExternalProcessorPayment, :count).by(1)
      expect(ExternalProcessorPayment.last.person).to eq(person)
    end

    it "resolves person via Stripe::Customer.retrieve fallback" do
      other_id = "ch_no_pc"
      allow(stripe_charge).to receive(:id).and_return(other_id)
      allow(stripe_charge).to receive(:customer).and_return("cus_external")
      allow(Stripe::Customer).to receive(:retrieve)
        .with("cus_external")
        .and_return(double(email: person.email))

      expect { processor.call(event) }.to change(ExternalProcessorPayment, :count).by(1)
      expect(ExternalProcessorPayment.last.person).to eq(person)
    end

    it "falls back to External Payer when no email can be resolved" do
      other_id = "ch_no_pc"
      allow(stripe_charge).to receive(:id).and_return(other_id)

      expect { processor.call(event) }.to change(ExternalProcessorPayment, :count).by(1)
      epp = ExternalProcessorPayment.last
      expect(epp.person.first_name).to eq("External")
      expect(epp.person.last_name).to eq("Payer")
    end

    it "reuses existing External Payer record" do
      other_id = "ch_no_pc"
      allow(stripe_charge).to receive(:id).and_return(other_id)
      existing = Person.find_or_create_by!(first_name: "External", last_name: "Payer")

      expect { processor.call(event) }.not_to change(Person, :count)
      expect(ExternalProcessorPayment.last.person).to eq(existing)
    end
  end

  describe "payment creation" do
    it "sets amount_cents and currency from the charge" do
      processor.call(event)
      epp = ExternalProcessorPayment.last
      expect(epp).to have_attributes(amount_cents: 30_00, currency: "usd")
    end

    it "sets amount_cents_remaining equal to amount_cents" do
      processor.call(event)
      expect(ExternalProcessorPayment.last.amount_cents_remaining).to eq(30_00)
    end

    it "stores stripe charge data in metadata and sets stripe_charge_id column" do
      processor.call(event)
      epp = ExternalProcessorPayment.last
      expect(epp.stripe_charge_id).to eq(stripe_charge_id)
      expect(epp.metadata["stripe_charge"]).to be_a(Hash)
    end
  end
end
