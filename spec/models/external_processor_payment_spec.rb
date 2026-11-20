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

  describe "billing details" do
    def payment_for(billing_details:, payer: person, payment_method_type: nil)
      stripe_charge = { "billing_details" => billing_details }
      stripe_charge["payment_method_details"] = { "type" => payment_method_type } if payment_method_type

      create(
        :external_processor_payment,
        person: payer,
        metadata: { "stripe_charge" => stripe_charge }
      )
    end

    it "reads the billing fields from Stripe metadata" do
      payment = payment_for(
        billing_details: {
          "name" => "Lisa Wilson",
          "email" => "andream@flintridge.org",
          "phone" => "+1 555 0100",
          "address" => { "postal_code" => "91103", "country" => "US" }
        },
        payment_method_type: "link"
      )

      expect(payment.stripe_billing_name).to eq("Lisa Wilson")
      expect(payment.stripe_billing_email).to eq("andream@flintridge.org")
      expect(payment.stripe_billing_phone).to eq("+1 555 0100")
      expect(payment.stripe_billing_address).to eq("91103, US")
      expect(payment.stripe_payment_method_type).to eq("link")
    end

    it "returns empty billing details when the payment has no Stripe charge metadata" do
      payment = create(:external_processor_payment, person: person)

      expect(payment.stripe_billing_details).to eq({})
      expect(payment.stripe_billing_name).to be_nil
    end

    it "doesn't flag a matching name" do
      payer = create(:person, first_name: "Andrea-Isabel", last_name: "Magat")
      payment = payment_for(billing_details: { "name" => "Andrea-Isabel Magat" }, payer: payer)

      expect(payment.billing_name_differs_from_payer?).to be(false)
    end

    it "ignores case, whitespace, name order, and middle initials" do
      payer = create(:person, first_name: "Lisa", last_name: "Wilson")
      payment = payment_for(billing_details: { "name" => "  wilson,   LISA d. " }, payer: payer)

      expect(payment.billing_name_differs_from_payer?).to be(false)
    end

    it "treats a hyphenated first name as the same as its first part" do
      payer = create(:person, first_name: "Andrea-Isabel", last_name: "Magat")
      payment = payment_for(billing_details: { "name" => "Andrea Magat" }, payer: payer)

      expect(payment.billing_name_differs_from_payer?).to be(false)
    end

    it "flags a different billing name" do
      payer = create(:person, first_name: "Andrea-Isabel", last_name: "Magat")
      payment = payment_for(billing_details: { "name" => "Lisa Wilson" }, payer: payer)

      expect(payment.billing_name_differs_from_payer?).to be(true)
    end

    it "doesn't flag a blank billing name" do
      payment = payment_for(billing_details: { "name" => nil })

      expect(payment.billing_name_differs_from_payer?).to be(false)
    end
  end
end
