module TitleDisplayHelper
  def title_with_badges(record, font_size: "text-lg", record_title: nil,
                        show_hidden_badge: true, display_windows_type: false)
    fragments = []
    home_page = controller_name == "home" || controller_path.start_with?("home/")

    # --- Hidden badge ---
    if show_hidden_badge && !home_page && record.respond_to?(:published?) && !record.published?
      icon = content_tag(:span, content_tag(:i, "", class: "fa-solid fa-eye-slash"), class: "inline-flex justify-center w-5")
      fragments << content_tag(
        :span,
        icon + content_tag(:span, "Unpublished", class: "ml-1"),
        class: "inline-flex items-center pl-2 pr-3 py-0.5 rounded-full
              text-sm font-medium bg-blue-100 text-gray-600 whitespace-nowrap"
      )
    end

    # --- Public + Featured badges (grouped on same row) ---
    visibility_badges = []

    if user_signed_in? && !home_page &&
       record.respond_to?(:publicly_visible?) && record.publicly_visible?
      icon = content_tag(:span, content_tag(:i, "", class: "fa-solid fa-globe"), class: "inline-flex justify-center w-5")
      visibility_badges << content_tag(
        :span,
        icon + content_tag(:span, "Public", class: "ml-1"),
        class: "inline-flex items-center pl-2 pr-3 py-0.5 rounded-full
              text-sm font-medium bg-violet-100 text-violet-800 whitespace-nowrap"
      )
    end

    if user_signed_in? && !home_page && record.respond_to?(:featured?) && record.featured?
      icon = content_tag(:span, "🌟", class: "inline-flex justify-center w-5")
      visibility_badges << content_tag(
        :span,
        icon + content_tag(:span, "Featured", class: "ml-1"),
        class: "inline-flex items-center pl-2 pr-3 py-0.5 rounded-full
              text-sm font-medium bg-yellow-100 text-yellow-800 whitespace-nowrap"
      )
    end

    if visibility_badges.any?
      fragments << content_tag(:span, safe_join(visibility_badges, " "), class: "inline-flex items-center gap-2 flex-nowrap")
    end

    # --- Hidden from search badge (publicly accessible, but excluded from portal searches) ---
    if current_user&.super_user? && !home_page &&
       record.respond_to?(:hidden_from_search?) && record.hidden_from_search?
      icon = content_tag(:span, content_tag(:i, "", class: "fa-solid fa-filter-circle-xmark"), class: "inline-flex justify-center w-5")
      fragments << content_tag(
        :span,
        icon + content_tag(:span, "Hidden from search", class: "ml-1"),
        class: "inline-flex items-center pl-2 pr-3 py-0.5 rounded-full
              text-sm font-medium bg-amber-100 text-amber-800 whitespace-nowrap"
      )
    end

    # --- Publicly Featured badge ---
    if !home_page && record.respond_to?(:publicly_featured?) && record.publicly_featured?
      label = user_signed_in? ? "Public Featured" : "Featured"
      icon = content_tag(:span, purple_star_svg, class: "inline-flex justify-center w-5")
      fragments << content_tag(
        :span,
        icon + content_tag(:span, label, class: "ml-1"),
        class: "inline-flex items-center pl-2 pr-3 py-0.5 rounded-full
              text-sm font-medium bg-purple-100 text-purple-800 whitespace-nowrap"
      )
    end

    # --- Instructional badge ---
    if record.respond_to?(:is_instructional) && record.is_instructional?
      icon = content_tag(:span, content_tag(:i, "", class: "fa-solid fa-graduation-cap"), class: "inline-flex justify-center w-5")
      fragments << content_tag(
        :span,
        icon + content_tag(:span, "Instructional", class: "ml-1"),
        class: "inline-flex items-center pl-2 pr-3 py-0.5 rounded-full
              text-sm font-medium bg-teal-100 text-teal-800 whitespace-nowrap"
      )
    end

    # --- Promoted from story idea badge ---
    if record.respond_to?(:story_idea) && record.story_idea.present?
      icon = content_tag(:span, content_tag(:i, "", class: "fa-solid fa-arrow-up-from-bracket"), class: "inline-flex justify-center w-5")
      fragments << content_tag(
        :span,
        icon + content_tag(:span, "Promoted", class: "ml-1"),
        class: "inline-flex items-center pl-2 pr-3 py-0.5 rounded-full
              text-sm font-medium bg-green-100 text-green-800 whitespace-nowrap"
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

  private

  # References the purple star SVG symbol defined in shared/_svg_symbols.html.erb.
  def purple_star_svg
    '<svg width="1.2em" height="1.2em" style="vertical-align:-0.2em"><use href="#purple-star"/></svg>'.html_safe
  end
end
