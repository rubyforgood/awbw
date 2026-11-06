class MembershipReport
  VIEWS = %w[ collected outstanding closed_out still_owing ended ].freeze

  Summary = Data.define(
    :revenue_cents, :outstanding_cents, :ended_count, :closed_out_count, :still_owing_count
  )

  attr_reader :year

  def initialize(year: nil)
    if year.to_s == "all"
      @year = nil
    else
      parsed = Integer(year, exception: false)
      @year = parsed if parsed&.positive? && parsed <= Date.current.year
      @year ||= Date.current.year
    end
  end

  def year_options
    first = Membership.minimum(:start_date)&.year
    return [ Date.current.year ] if first.blank?

    (first..Date.current.year).to_a.reverse
  end

  def summary
    @summary ||= Summary.new(
      revenue_cents: revenue_cents,
      outstanding_cents: outstanding_cents,
      ended_count: ended_count,
      closed_out_count: closed_out_count,
      still_owing_count: still_owing_count
    )
  end

  def collected_invoices
    invoices_in_scope
      .where(id: paid_invoice_ids)
      .includes(:allocations, :charge_attempts, membership: :person)
      .order(start_date: :desc)
  end

  def outstanding_invoices
    outstanding_invoice_scope
      .not_paid_in_full
      .includes(:allocations, :charge_attempts, membership: :person)
      .order(start_date: :desc)
  end

  def ended_memberships
    ended_scope
      .includes(person: :user, membership_invoices: :allocations)
      .order(end_date: :desc)
  end

  def closed_out_memberships
    ended_scope
      .where.not(person_id: owing_person_ids)
      .includes(person: :user, membership_invoices: :allocations)
      .order(end_date: :desc)
  end

  def still_owing_memberships
    ended_scope
      .where(person_id: owing_person_ids)
      .includes(person: :user, membership_invoices: :allocations)
      .order(end_date: :desc)
  end

  private

  def year_range
    return unless year

    @year_range ||= Date.new(year, 1, 1)..[ Date.new(year, 12, 31), Date.current ].min
  end

  def revenue_cents
    @revenue_cents ||= allocations_for(invoices_in_scope)
      .where(source_type: Payment.polymorphic_name)
      .sum(:amount)
      .to_i
  end

  def outstanding_cents
    @outstanding_cents ||= invoice_balances(outstanding_invoice_scope).sum
  end

  def ended_count
    ended_person_ids.size
  end

  def closed_out_count
    closed_out_person_ids.size
  end

  def still_owing_count
    ended_count - closed_out_count
  end

  def invoices_in_scope
    @invoices_in_scope ||= year ? MembershipInvoice.where(start_date: year_range) : MembershipInvoice.all
  end

  def outstanding_invoice_scope
    @outstanding_invoice_scope ||= begin
      scope = invoices_in_scope
      scope = scope.where(start_date: ..Date.current) unless year
      scope
    end
  end

  def allocations_for(invoice_scope)
    Allocation.where(
      allocatable_type: MembershipInvoice.polymorphic_name,
      allocatable_id: invoice_scope.select(:id)
    )
  end

  def invoice_balances(invoice_scope)
    invoice_scope
      .left_joins(:allocations)
      .group("membership_invoices.id", "membership_invoices.cost_cents")
      .pluck(Arel.sql("membership_invoices.cost_cents - COALESCE(SUM(allocations.amount), 0)"))
      .map { |balance| [ balance, 0 ].max }
  end

  def paid_invoice_ids
    Allocation
      .where(allocatable_type: MembershipInvoice.polymorphic_name, source_type: Payment.polymorphic_name)
      .group(:allocatable_id)
      .having("SUM(amount) > 0")
      .select(:allocatable_id)
  end

  def ended_scope
    @ended_scope ||= year ? Membership.where(end_date: year_range) : Membership.ended
  end

  def ended_person_ids
    @ended_person_ids ||= ended_scope.distinct.pluck(:person_id)
  end

  def owing_person_ids
    @owing_person_ids ||= ended_scope
      .where(id: started_unpaid_invoices.select(:membership_id))
      .distinct
      .pluck(:person_id)
  end

  def closed_out_person_ids
    @closed_out_person_ids ||= ended_person_ids - owing_person_ids
  end

  def started_unpaid_invoices
    MembershipInvoice
      .where(membership_id: ended_scope.select(:id), start_date: ..Date.current)
      .not_paid_in_full
  end
end
