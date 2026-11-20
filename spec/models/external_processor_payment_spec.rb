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
    it "reads the billing fields from Stripe metadata" do
      payment = create(
        :external_processor_payment,
        person: person,
        metadata: {
          "stripe_charge" => {
            "billing_details" => {
              "name" => "Lisa Wilson",
              "email" => "andream@flintridge.org",
              "phone" => "+1 555 0100",
              "address" => { "postal_code" => "91103", "country" => "US" }
            },
            "payment_method_details" => { "type" => "link" }
          }
        }
      )

      expect(payment.stripe_billing_name).to eq("Lisa Wilson")
      expect(payment.stripe_billing_email).to eq("andream@flintridge.org")
      expect(payment.stripe_billing_phone).to eq("+1 555 0100")
      expect(payment.stripe_billing_address).to eq("91103, US")
      expect(payment.stripe_payment_method_type).to eq("link")
    end
  end
end
