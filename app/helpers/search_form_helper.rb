module SearchFormHelper
  # Shared filter/search-bar field + label styling. Helpers (not `@apply` CSS or a
  # partial) because these classes decorate ~100 heterogeneous controls — selects,
  # remote-selects, multi-selects, date/number/text inputs — that can't funnel through
  # one field partial, and labels appear as static tags, label_tag, and var-driven
  # classes alike. Tailwind v4 scans app/helpers via @source, so the literal classes
  # still get generated. Callers add per-field tweaks via `extra:` (e.g. "pr-10",
  # "bg-white", "search-select-placeholder", "italic").
  SEARCH_FIELD_CLASSES = "w-full rounded-lg border border-gray-300 px-3 py-2 text-gray-800 shadow-sm " \
    "placeholder:text-sm placeholder:text-gray-400 " \
    "focus:border-blue-500 focus:ring focus:ring-blue-200 focus:outline-none".freeze

  SEARCH_LABEL_CLASSES = "block text-xs font-semibold uppercase text-gray-500 tracking-wide mb-1".freeze

  def search_field_class(extra: nil)
    [ SEARCH_FIELD_CLASSES, extra ].compact.join(" ")
  end

  def search_label_class(extra: nil)
    [ SEARCH_LABEL_CLASSES, extra ].compact.join(" ")
  end
end
