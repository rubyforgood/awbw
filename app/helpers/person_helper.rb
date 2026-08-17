module PersonHelper
  def person_profile_button(person, truncate_at: nil, subtitle: nil, display_name: nil, data: {}, inactive: false, tint: nil, path_params: {}, width_class: "w-full", compact: false)
    # Compact mode shrinks the whole control (padding, avatar, type) for dense
    # tables like the registrants roster where horizontal space is at a premium.
    padding = compact ? "px-2 py-1" : "px-4 py-2"
    avatar_size = compact ? "w-6 h-6" : "w-10 h-10"
    initial_text_size = compact ? "text-xs" : "text-lg"
    name_text_size = compact ? "text-xs" : ""

    if inactive
      bg = "bg-gray-100"
      hover_bg = "hover:bg-gray-200"
      text = "text-gray-400"
      border = "border-gray-300"
    elsif tint == :facilitator
      bg = "bg-purple-100"
      hover_bg = "hover:bg-purple-200"
      text = DomainTheme.text_class_for(:people)
      border = "border-purple-300"
    elsif tint == :muted
      bg = "bg-white"
      hover_bg = "hover:bg-gray-50"
      text = DomainTheme.text_class_for(:people)
      border = "border-gray-300"
    else
      bg = DomainTheme.bg_class_for(:people, intensity: 100)
      hover_bg = DomainTheme.bg_class_for(:people, intensity: 100, hover: true)
      text = DomainTheme.text_class_for(:people)
      border = DomainTheme.border_class_for(:people)
    end
    shadow = tint ? "shadow-none" : "shadow-sm"

    full_name = display_name || person.try(:name) || person.to_s
    hover_title = [ full_name, subtitle ].compact_blank.join(" — ")

    # Only touch person.user when the viewer is actually allowed to see a pending
    # email change — this keeps the button from firing an N+1 :user lookup per row
    # for anonymous/public viewers on people-heavy pages (e.g. organizations#show).
    unconfirmed_email = person.user&.unconfirmed_email if allowed_to?(:show_email_change?, person)
    show_email_change = unconfirmed_email.present?

    link_to person_path(person, **path_params),
            data: { turbo_prefetch: false }.merge(data),
            title: hover_title,
            class: "group relative flex items-center gap-2
                    #{width_class} #{padding}
                    border #{border} #{bg} #{hover_bg} rounded-lg
                    transition-colors duration-200
                    font-medium #{shadow} leading-none
                    overflow-hidden" do
      person = person.decorate

      # --- Avatar ---
      avatar = if person.avatar.present?
        image_tag person.avatar.variant(:thumbnail),
                  class: "#{avatar_size} rounded-full object-cover border border-gray-300 shadow-sm flex-shrink-0"
      else
        content_tag(:span, person.name.to_s.first.to_s.upcase,
                    class: "#{avatar_size} rounded-full flex items-center justify-center
                            bg-sky-200 text-sky-700 font-bold #{initial_text_size}
                            border border-sky-300 shadow-sm flex-shrink-0")
      end

      display_name = display_name || person.name.to_s
      display_name = truncate(display_name, length: truncate_at) if truncate_at

      name = content_tag(
        :span,
        display_name,
        class: "font-semibold #{name_text_size} #{text} truncate"
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

      warning_tag = if show_email_change
        content_tag(:span,
                    tag.i(class: "fa-solid fa-triangle-exclamation"),
                    class: "flex-shrink-0 ml-auto text-yellow-500",
                    title: "Email change to #{unconfirmed_email} awaiting confirmation. " \
                           "Only the person and admins can see this; it is hidden from other profile visitors.")
      else
        "".html_safe
      end

      avatar + text_block + warning_tag
    end
  end
end
