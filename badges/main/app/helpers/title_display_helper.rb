module TitleDisplayHelper
  def title_with_badges(record, font_size: "text-lg", record_title: nil,
                        show_hidden_badge: false, display_windows_type: false)
    fragments = []

    # --- Hidden badge ---
    if show_hidden_badge && controller_name != "dashboard" && (
      record.respond_to?(:inactive?) && record.inactive? && controller_name != "dashboard" ||
      record.respond_to?(:published?) && !record.published?)
      fragments << content_tag(
        :span,
        content_tag(:i, "", class: "fa-solid fa-eye-slash mr-1") + " Hidden",
        class: "inline-flex items-center px-2 py-0.5 rounded-full
              text-sm font-medium bg-blue-100 text-gray-600 whitespace-nowrap"
      )
    end

    # --- Featured badge ---
    if record.respond_to?(:featured?) && record.featured? && controller_name != "dashboard"
      fragments << content_tag(
        :span,
        "🌟 Dashboard feature",
        class: "inline-flex items-center px-2 py-0.5 rounded-full
              text-sm font-medium bg-yellow-100 text-yellow-800 whitespace-nowrap"
      )
    end

    title_content = record_title || record.title.to_s

    if display_windows_type && record.respond_to?(:windows_type) && record.windows_type.present?
      title_content += " (#{record.windows_type.short_name})"
    end

    title_row = content_tag(
      :span,
      title_content.html_safe,
      class: "#{font_size} font-semibold text-gray-900 leading-tight"
    )

    # ---- Combine rows intelligently ----
    if fragments.any?
      content_tag :div, class: "flex flex-col" do
        safe_join([
                    content_tag(:div, safe_join(fragments), class: "flex flex-wrap items-center gap-2 mb-1"),
                    title_row
                  ])
      end
    else
      # No badges: just return the title with no empty div wrapper
      title_row
    end
  end
end
