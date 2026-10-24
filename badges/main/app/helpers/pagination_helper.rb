module PaginationHelper
  PER_PAGE_OPTIONS = [ 10, 25, 50, 100, 250 ].freeze

  # Keeps a size passed in the URL selectable, so the dropdown matches the page.
  def per_page_select_options(default)
    current = params[:number_of_items_per_page].to_i
    current = default unless current.positive?
    options_for_select((PER_PAGE_OPTIONS | [ current ]).sort, current)
  end

  def tailwind_paginate(collection, options = {})
    raw = collection.respond_to?(:object) ? collection.object : collection

    return nil unless raw.respond_to?(:total_pages)

    will_paginate(
      raw,
      {
        renderer: TailwindPaginationRenderer,
        inner_window: 2,
        previous_label: "<<",
        next_label: ">>"
      }.merge(options)
    )
  end
end
