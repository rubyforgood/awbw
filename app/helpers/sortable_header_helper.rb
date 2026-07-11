module SortableHeaderHelper
  # Font Awesome icon class for a sortable column, reflecting the active
  # @sort / @sort_direction. Inactive columns show the neutral two-way arrow.
  def sort_icon_class(column)
    return "fa-sort" unless @sort.to_s == column.to_s

    @sort_direction == "asc" ? "fa-arrow-up" : "fa-arrow-down"
  end

  # Builds a click-to-sort column-header link generator for the lazy
  # index/filter frames (stories, community_news, bookmarks,
  # workshop_variations). Bind it once per results partial, then call it per
  # column:
  #
  #   sort_link = sort_header_link(frame: "stories_results",
  #                                path: ->(p) { stories_path(p) },
  #                                base: params.permit(:query, :year).to_h.symbolize_keys)
  #   sort_link.call("title", "Title")
  #
  # `base` carries the current search/filter params so they survive a re-sort.
  # Clicking a fresh column sorts descending, then toggles to ascending.
  def sort_header_link(frame:, path:, base: {})
    ->(column, label) do
      direction = (@sort.to_s == column.to_s && @sort_direction == "desc") ? "asc" : "desc"
      link_to path.call(base.merge(sort: column, direction: direction, page: nil)),
              data: { turbo_frame: frame },
              class: "inline-flex items-center gap-1 text-gray-700 hover:text-gray-900" do
        safe_join([ label, tag.i("", class: "fa-solid #{sort_icon_class(column)} text-xs opacity-70") ], " ")
      end
    end
  end
end
