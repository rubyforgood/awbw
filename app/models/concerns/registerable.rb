module Registerable
  extend ActiveSupport::Concern

  # Shared behaviour for the two registration records that money is allocated to
  # and that grant a certificate: EventRegistration and
  # ContinuingEducationRegistration. Keeps their payment + certificate interfaces
  # identical so they can't drift.
  #
  # Includers must:
  #   - have an `allocations` association (as: :allocatable)
  #   - respond to `cost_cents` (EventRegistration delegates to event.cost_cents;
  #     ContinuingEducationRegistration has its own column)
  #   - define their own `certificate_available?` (the eligibility rules differ)
  #
  # The payment reads use the loaded `allocations` association when present, so
  # callers that preload it (rosters, onboarding matrix) pay no per-row queries.

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

  # Certificate delivery. Sending the certificate email is how it's issued, so
  # certificate_sent_at doubles as the "issued" marker. Each includer defines its
  # own #certificate_available? eligibility.
  def certificate_sent?
    certificate_sent_at.present?
  end

  def mark_certificate_sent!(at: Time.current)
    update!(certificate_sent_at: at)
  end
end
