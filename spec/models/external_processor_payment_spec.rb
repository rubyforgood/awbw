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
end
