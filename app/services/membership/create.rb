class Membership::Create
  Result = Struct.new(:membership, :errors, keyword_init: true) do
    def success? = errors.blank?
  end

  def self.call(person:, start_date:, cost_cents: nil, invoice_cost_cents: nil)
    new(person:, start_date:, cost_cents:, invoice_cost_cents:).call
  end

  def initialize(person:, start_date:, cost_cents: nil, invoice_cost_cents: nil)
    @person = person
    @start_date = start_date.to_date
    @cost_cents = cost_cents
    @invoice_cost_cents = invoice_cost_cents
  end

  def call
    membership = nil

    @person.with_lock do
      membership = @person.memberships.create!(
        start_date: @start_date,
        end_date: @start_date + Membership::INVOICE_PERIOD - 1.day,
        cost_cents: @cost_cents
      )

      membership.membership_invoices.create!(
        start_date: membership.start_date,
        end_date: membership.end_date,
        cost_cents: invoice_cost_cents(membership)
      )

      lock_other_memberships(membership)
    end

    Result.new(membership:, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(membership:, errors: e.record.errors.full_messages)
  end

  private

  def invoice_cost_cents(membership)
    return @invoice_cost_cents if @invoice_cost_cents

    membership.cost_cents || Membership.annual_cost_cents
  end

  def lock_other_memberships(membership)
    @person.memberships.where.not(id: membership.id).where(locked_at: nil).find_each(&:lock_for_history!)
  end
end
