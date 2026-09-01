module MarkHelper
  # The "marked" filter dropdown options shared by the taggings & subscriptions
  # indexes: All / Yes / No, filtering the boolean the tag/topic labels.
  MARK_FILTER_OPTIONS = [ [ "All", "" ], [ "Yes", "true" ], [ "No", "false" ] ].freeze

  # The word a tag/topic gives its mark, falling back to a generic label when the
  # admin hasn't named one.
  def mark_label_or_default(label)
    label.presence || "Marked"
  end

  # The ✓ / — cell shown in the taggings & subscriptions index rows, captioned
  # with the tag/topic's configured mark label when set.
  def marked_indicator(marked, label)
    return content_tag(:span, "—", class: "text-gray-300") unless marked

    content_tag(:span, class: "inline-flex items-center gap-1 text-sm font-medium text-green-700") do
      safe_join([ tag.i(class: "fa-solid fa-circle-check text-green-500"), mark_label_or_default(label) ], " ")
    end
  end
end
