module PersonHelper
  # Just the circular avatar (photo, or the name's first letter) as a link to the
  # person's profile — for dense tables that show the name in separate columns.
  def person_avatar_link(person, data: {}, path_params: {})
    decorated = person.decorate
    avatar = if decorated.avatar.present?
      image_tag decorated.avatar.variant(:thumbnail),
                class: "w-10 h-10 rounded-full object-cover border border-gray-300 shadow-sm"
    else
      content_tag(:span, decorated.name.to_s.first.to_s.upcase,
                  class: "w-10 h-10 rounded-full flex items-center justify-center
                          bg-sky-200 text-sky-700 font-bold text-lg
                          border border-sky-300 shadow-sm")
    end

    link_to avatar, person_path(person, **path_params),
            data: { turbo_prefetch: false }.merge(data),
            title: decorated.name,
            class: "inline-flex shrink-0 hover:opacity-80 transition-opacity"
  end

  def person_profile_button(person, truncate_at: nil, subtitle: nil, display_name: nil, data: {}, inactive: false, path_params: {})
    if inactive
      bg = "bg-gray-100"
      hover_bg = "hover:bg-gray-200"
      text = "text-gray-400"
      border = "border-gray-300"
    else
      bg = DomainTheme.bg_class_for(:people, intensity: 100)
      hover_bg = DomainTheme.bg_class_for(:people, intensity: 100, hover: true)
      text = DomainTheme.text_class_for(:people)
      border = DomainTheme.border_class_for(:people)
    end

    full_name = display_name || person.try(:name) || person.to_s
    hover_title = [ full_name, subtitle ].compact_blank.join(" — ")

    link_to person_path(person, **path_params),
            data: { turbo_prefetch: false }.merge(data),
            title: hover_title,
            class: "group relative flex items-center gap-2
                    w-full px-4 py-2
                    border #{border} #{bg} #{hover_bg} rounded-lg
                    transition-colors duration-200
                    font-medium shadow-sm leading-none
                    overflow-hidden" do
      person = person.decorate

      # --- Avatar ---
      avatar = if person.avatar.present?
        image_tag person.avatar.variant(:thumbnail),
                  class: "w-10 h-10 rounded-full object-cover border border-gray-300 shadow-sm flex-shrink-0"
      else
        content_tag(:span, person.name.to_s.first.to_s.upcase,
                    class: "w-10 h-10 rounded-full flex items-center justify-center
                            bg-sky-200 text-sky-700 font-bold text-lg
                            border border-sky-300 shadow-sm flex-shrink-0")
      end

      display_name = display_name || person.name.to_s
      display_name = truncate(display_name, length: truncate_at) if truncate_at

      name = content_tag(
        :span,
        display_name,
        class: "font-semibold #{text} truncate"
      )

      subtitle_tag = if subtitle.present?
        "<!--email_off-->".html_safe +
          content_tag(:span, subtitle, class: "text-xs text-gray-500 font-normal truncate") +
          "<!--email_on-->".html_safe
      else
        "".html_safe
      end

      text_block = content_tag(
        :div,
        name + subtitle_tag,
        class: "flex flex-col leading-tight text-left min-w-0"
      )

      avatar + text_block
    end
  end
end
