module PaginationHelper
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
