class DuesRegistrationDecorator < ApplicationDecorator
  Badge = Struct.new(:label, :icon, :classes, keyword_init: true)

  BADGE_CLASSES = {
    green: "bg-green-50 text-green-700 border-green-200",
    blue: "bg-blue-50 text-blue-700 border-blue-200",
    amber: "bg-amber-50 text-amber-700 border-amber-200",
    red: "bg-red-50 text-red-700 border-red-200",
    gray: "bg-gray-50 text-gray-600 border-gray-200"
  }.freeze

  def status_badge(as_of: Date.current)
    return badge("Upcoming", "fa-solid fa-hourglass-start", :blue) if start_date > as_of
    return badge("Overdue", "fa-solid fa-triangle-exclamation", :red) if overdue?(as_of)
    return badge("Expired", "fa-solid fa-clock-rotate-left", :gray) if end_date < as_of
    return badge("Paid", "fa-solid fa-circle-check", :green) if paid_in_full?

    badge("#{h.dollars_from_cents(remaining_cost)} due", "fa-solid fa-dollar-sign", :amber)
  end

  def term_range
    "#{format_date(start_date)} – #{format_date(end_date)}"
  end

  def cost
    h.dollars_from_cents(cost_cents)
  end

  def paid
    h.dollars_from_cents(allocations_sum)
  end

  def remaining
    h.dollars_from_cents(remaining_cost)
  end

  def comped?
    cost_cents.zero?
  end

  private

  def badge(label, icon, color)
    Badge.new(label: label, icon: icon, classes: BADGE_CLASSES.fetch(color))
  end

  def format_date(date)
    date&.strftime("%b %-d, %Y")
  end
end
