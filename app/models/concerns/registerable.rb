module Registerable
  extend ActiveSupport::Concern

  # Includers must:
  #   - have an `allocations` association (as: :allocatable)
  #   - respond to `cost_cents` (EventRegistration delegates to event.cost_cents;
  #     ContinuingEducationRegistration and MembershipInvoice have their own column)
  #   - respond to `registrant`
  #

  # Total covered by every allocation — payments, discounts, scholarships.
  def allocations_sum
    return allocations.to_a.sum(&:amount) if allocations.loaded?
    allocations.sum(:amount)
  end

  # Cash only (excludes scholarships and discounts).
  def payments_sum
    return allocations.to_a.select { |a| a.source_type == Payment.polymorphic_name }.sum(&:amount) if allocations.loaded?
    allocations.where(source_type: Payment.polymorphic_name).sum(:amount)
  end

  # True once actual money has been received (cash, check, or card) — as opposed
  # to a balance settled purely by scholarship or discount. Gates the receipt and
  # W-9, which only apply once a real payment is on file.
  def payment_received?
    payments_sum.positive?
  end

  # Comp/discount coverage only (excludes payments and scholarships).
  def discount_sum
    return allocations.to_a.select { |a| a.source_type == "Discount" }.sum(&:amount) if allocations.loaded?
    allocations.where(source_type: "Discount").sum(:amount)
  end

  def discounted?
    return allocations.to_a.any? { |a| a.source_type == "Discount" } if allocations.loaded?
    allocations.where(source_type: "Discount").exists?
  end

  def remaining_cost
    [ cost_cents.to_i - allocations_sum, 0 ].max
  end

  # A free (or zero-cost) registration is paid by definition.
  def paid_in_full?
    return true if cost_cents.to_i <= 0
    allocations_sum >= cost_cents.to_i
  end

  def partially_paid?
    !paid_in_full? && payments_sum.to_i.positive?
  end
end
