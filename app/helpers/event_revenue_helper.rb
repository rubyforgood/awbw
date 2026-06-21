module EventRevenueHelper
  # A small, neutral year-over-year change indicator for a money figure, e.g.
  # "▲ $1,200" / "▼ $400". Direction is shown but not coloured good/bad, since
  # "up" is favourable for fees and net but not for subsidy. Returns nil when
  # there's no prior period or no change.
  def revenue_delta(current_cents, prior_cents)
    return nil if prior_cents.nil?
    delta = current_cents - prior_cents
    return nil if delta.zero?
    arrow = delta.positive? ? "▲" : "▼"
    content_tag(:span, "#{arrow} #{dollars_from_cents(delta.abs)}",
                class: "text-xs text-gray-400 tabular-nums")
  end

  # Net can be negative (the org subsidised more than it took in). Render
  # negatives as "-$1,200" so the sign reads clearly.
  def signed_dollars_from_cents(cents)
    return dollars_from_cents(cents) unless cents.negative?
    "-#{dollars_from_cents(cents.abs)}"
  end
end
