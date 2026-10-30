class MembershipPaymentLink
  def self.invoice_for(payment) = new(payment).invoice

  def initialize(payment)
    @payment = payment
  end

  def invoice
    @invoice ||= invoice_from_attempt || invoice_from_metadata
  end

  def credit? = invoice.nil? || invoice.paid_in_full?

  def unpaid? = invoice.present? && !invoice.paid_in_full?

  private

  def invoice_from_attempt
    return if @payment.pay_charge_id.blank?

    MembershipChargeAttempt.find_by(pay_charge_id: @payment.pay_charge_id)&.membership_invoice
  end

  def invoice_from_metadata
    metadata = (@payment.metadata || {}).to_h
    id = metadata["membership_invoice_id"] ||
      metadata.dig("stripe_charge", "metadata", "membership_invoice_id")
    return if id.blank?

    MembershipInvoice.find_by(id:)
  end
end
