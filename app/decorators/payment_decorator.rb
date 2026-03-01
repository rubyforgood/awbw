class PaymentDecorator < ApplicationDecorator
  def title
    "Payment ##{id}"
  end

  def detail(length: nil)
    "#{formatted_amount} - #{status.humanize}"
  end

  def formatted_amount
    "$#{'%.2f' % (amount_cents / 100.0)}"
  end

  def status_badge
    style = STATUS_BADGE_STYLES[status] || "bg-gray-50 text-gray-500 border-gray-200"
    h.content_tag(:span, status.humanize,
      class: "inline-flex items-center rounded-full text-xs font-medium border px-3 py-0.5 #{style}")
  end

  STATUS_BADGE_STYLES = {
    "succeeded"          => "bg-green-50 text-green-700 border-green-200",
    "pending"            => "bg-yellow-50 text-yellow-700 border-yellow-200",
    "requires_action"    => "bg-amber-50 text-amber-700 border-amber-200",
    "processing"         => "bg-blue-50 text-blue-700 border-blue-200",
    "failed"             => "bg-red-50 text-red-700 border-red-200",
    "canceled"           => "bg-gray-50 text-gray-500 border-gray-200",
    "refunded"           => "bg-purple-50 text-purple-700 border-purple-200",
    "partially_refunded" => "bg-orange-50 text-orange-700 border-orange-200"
  }.freeze
end
