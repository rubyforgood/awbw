module MarkHelper
  # The "marked" filter dropdown options shared by the taggings & subscriptions
  # indexes: All / Yes / No, filtering the boolean the tag/topic labels.
  MARK_FILTER_OPTIONS = [ [ "All", "" ], [ "Yes", "true" ], [ "No", "false" ] ].freeze

  # The word a tag/topic gives its mark, falling back to a generic label when the
  # admin hasn't named one.
  def mark_label_or_default(label)
    label.presence || "Marked"
  end
end
