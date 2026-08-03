module EventParticipationHelper
  # A small, neutral year-over-year change indicator for a headcount, e.g.
  # "▲ 12" / "▼ 3". Direction only, uncoloured. Returns nil when there's no prior
  # period or no change.
  def participation_delta(current_count, prior_count)
    return nil if prior_count.nil?
    delta = current_count - prior_count
    return nil if delta.zero?
    arrow = delta.positive? ? "▲" : "▼"
    content_tag(:span, "#{arrow} #{number_with_delimiter(delta.abs)}",
                class: "text-xs text-gray-400 tabular-nums")
  end
end
