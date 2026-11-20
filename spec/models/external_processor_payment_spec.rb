require "rails_helper"

RSpec.describe ExternalProcessorPayment do
  let(:pay_charge) { create(:pay_charge) }
  let(:person) { create(:person) }

  describe "pay_charge validation" do
    it "is valid with a pay_charge_id on create" do
      payment = ExternalProcessorPayment.new(
        person: person,
        pay_charge: pay_charge,
        amount_cents: 1000,
        currency: "usd"
      )
      expect(payment).to be_valid
    end

    it "is invalid without a pay_charge_id on create" do
      payment = ExternalProcessorPayment.new(
        person: person,
        amount_cents: 1000,
        currency: "usd"
      )
      expect(payment).not_to be_valid
      expect(payment.errors[:pay_charge_id]).to include("must exist")
    end

    it "skips pay_charge validation when skip_pay_charge_validation is true" do
      payment = ExternalProcessorPayment.new(
        person: person,
        amount_cents: 1000,
        currency: "usd"
      )
      payment.skip_pay_charge_validation = true
      expect(payment).to be_valid
    end

    it "does not validate pay_charge presence on update" do
      payment = ExternalProcessorPayment.create!(
        person: person,
        pay_charge: pay_charge,
        amount_cents: 1000,
        currency: "usd"
      )
      payment.pay_charge_id = nil
      expect(payment).to be_valid
    end
  end

  describe "cardholder name" do
    def payment_for(cardholder_name:, payer: person)
      create(
        :external_processor_payment,
        person: payer,
        metadata: { "stripe_charge" => { "billing_details" => { "name" => cardholder_name } } }
      )
    end

    it "reads the name from the Stripe charge metadata" do
      payment = payment_for(cardholder_name: "Lisa Wilson")

      expect(payment.stripe_cardholder_name).to eq("Lisa Wilson")
    end

    it "returns nil when the payment has no Stripe charge metadata" do
      payment = create(:external_processor_payment, person: person)

      expect(payment.stripe_cardholder_name).to be_nil
    end

    it "doesn't flag a matching name" do
      payer = create(:person, first_name: "Andrea-Isabel", last_name: "Magat")
      payment = payment_for(cardholder_name: "Andrea-Isabel Magat", payer: payer)

      expect(payment.cardholder_differs_from_payer?).to be(false)
    end

    it "ignores case, whitespace, name order, and middle initials" do
      payer = create(:person, first_name: "Lisa", last_name: "Wilson")
      payment = payment_for(cardholder_name: "  wilson,   LISA d. ", payer: payer)

      expect(payment.cardholder_differs_from_payer?).to be(false)
    end

    it "treats a hyphenated first name as the same as its first part" do
      payer = create(:person, first_name: "Andrea-Isabel", last_name: "Magat")
      payment = payment_for(cardholder_name: "Andrea Magat", payer: payer)

      expect(payment.cardholder_differs_from_payer?).to be(false)
    end

    it "flags a different cardholder" do
      payer = create(:person, first_name: "Andrea-Isabel", last_name: "Magat")
      payment = payment_for(cardholder_name: "Lisa Wilson", payer: payer)

      expect(payment.cardholder_differs_from_payer?).to be(true)
    end

    it "doesn't flag a blank cardholder" do
      payment = payment_for(cardholder_name: nil)

      expect(payment.cardholder_differs_from_payer?).to be(false)
    end
  end
end
