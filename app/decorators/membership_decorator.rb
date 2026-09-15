class MembershipDecorator < ApplicationDecorator
  def cost_label
    return "Standard (#{h.dollars_from_cents(Membership::ANNUAL_COST_CENTS)})" if cost_cents.nil?

    "Locked at #{h.dollars_from_cents(cost_cents)}"
  end

  def covered_on?(date = Date.current)
    membership_invoices.any? { |invoice| invoice.active_on?(date) }
  end

  def current_invoice
    membership_invoices.find { |invoice| invoice.active_on?(Date.current) } || membership_invoices.first
  end

  # The invoice that puts this membership in the given overview section, or nil.
  # Computed over the preloaded invoices so the admin index pays no per-row query.
  def section_invoice(section_key, as_of: Date.current)
    case section_key.to_sym
    when :current then membership_invoices.find { |invoice| invoice.active_on?(as_of) }
    when :upcoming then membership_invoices.find { |invoice| invoice.start_date && invoice.start_date > as_of }
    when :within_grace then membership_invoices.find { |invoice| invoice.within_grace?(as_of) }
    when :overdue then membership_invoices.find { |invoice| invoice.overdue?(as_of) }
    end
  end

  def status_label
    return "Active" unless cancelled?

    "Cancelled #{cancelled_at.strftime("%b %-d, %Y")}"
  end
end
