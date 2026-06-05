module PersonHelper
  # Builds [ label, id ] pairs for a person select. Shows just the name, adding
  # the email only to disambiguate people who share a full name.
  def person_select_options(people)
    duplicate_names = people.map(&:full_name).tally.select { |_, count| count > 1 }.keys.to_set
    people.map do |person|
      label = duplicate_names.include?(person.full_name) ? person.full_name_with_email : person.full_name
      [ label, person.id ]
    end
  end

  def person_profile_button(person, truncate_at: nil, subtitle: nil, display_name: nil, data: {}, inactive: false)
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

    link_to person_path(person),
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
