# Applies an already-recorded payment to a membership invoice. This is pure local
# accounting: it never creates a Stripe charge, refunds anything, or moves money.
class Membership::Reconcile::Payment
  Result = Data.define(:status, :payment, :allocation, :amount_cents, :message, :errors) do
    def success? = errors.blank?
    def allocated? = %i[applied already_applied].include?(status)
  end

  def self.call(invoice:, payment:)
    new(invoice:, payment:).call
  end

  def initialize(invoice:, payment:)
    @invoice = invoice
    @payment = payment
  end

  def call
    if @payment.person_id.present? && @payment.person_id != @invoice.person.id
      return failure("This payment belongs to a different person.")
    end

    return already_applied_result if already_applied?
    return no_op(:payment_exhausted, "This payment has no amount left to apply.") unless payment_remaining.positive?

    @invoice.with_lock do
      @invoice.allocations.reload

      @payment.with_lock do
        @payment.reload

        next already_applied_result if already_applied?

        next no_op(:payment_exhausted, "This payment has no amount left to apply.") unless payment_remaining.positive?
        next no_op(:invoice_paid, "The invoice is already paid in full. The payment remains unallocated.") unless @invoice.remaining_cost.positive?

        amount = [ payment_remaining, @invoice.remaining_cost ].min
        allocation = Allocation.create!(source: @payment, allocatable: @invoice, amount:)

        Result.new(status: :applied, payment: @payment.reload, allocation:,
                   amount_cents: amount,
                   message: "Applied #{MoneyFormatter.dollars_from_cents(amount)} to the invoice.",
                   errors: [])
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.to_sentence)
  end

  private

  def payment_remaining = @payment.amount_cents_remaining.to_i

  def already_applied?
    existing_allocation.present?
  end

  def existing_allocation
    @payment.allocations.find_by(
      allocatable_type: @invoice.class.polymorphic_name,
      allocatable_id: @invoice.id
    )
  end

  def already_applied_result
    Result.new(status: :already_applied, payment: @payment, allocation: existing_allocation,
               amount_cents: 0, message: "This payment is already applied to the invoice.", errors: [])
  end

  def no_op(status, message)
    Result.new(status:, payment: @payment, allocation: nil, amount_cents: 0, message:, errors: [])
  end

  def failure(message)
    Result.new(status: :error, payment: @payment, allocation: nil, amount_cents: 0,
               message:, errors: [ message ])
  end
end
