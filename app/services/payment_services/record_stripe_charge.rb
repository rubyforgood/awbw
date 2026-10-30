module PaymentServices
  class RecordStripeCharge
    def self.call(charge:, person:, pay_charge: nil, external_origin: true, metadata: nil)
      new(
        charge:,
        person:,
        pay_charge:,
        external_origin:,
        metadata:
      ).call
    end

    def initialize(charge:, person:, pay_charge:, external_origin:, metadata:)
      @charge = charge
      @person = person
      @pay_charge = pay_charge
      @external_origin = external_origin
      @metadata = metadata || { stripe_charge: charge.to_hash }
    end

    def call
      existing = ExternalProcessorPayment.find_by(stripe_charge_id: @charge.id)
      return existing if existing.present?

      payment = ExternalProcessorPayment.new(
        stripe_charge_id: @charge.id,
        external_origin: @external_origin,
        person: @person,
        amount_cents: @charge.amount,
        amount_cents_remaining: @charge.amount,
        currency: @charge.currency,
        pay_charge: @pay_charge,
        metadata: @metadata
      )
      payment.skip_pay_charge_validation = @pay_charge.blank?
      payment.save!
      payment
    rescue ActiveRecord::RecordNotUnique
      ExternalProcessorPayment.find_by!(stripe_charge_id: @charge.id)
    end
  end
end
