module EventHelper
  def event_profile_button(event, truncate_at: nil, subtitle: nil, data: {})
    bg = DomainTheme.bg_class_for(:events, intensity: 100)
    hover_bg = DomainTheme.bg_class_for(:events, intensity: 100, hover: true)
    text = DomainTheme.text_class_for(:events)
    border = DomainTheme.border_class_for(:events)

    link_to event_path(event),
            data: data,
            style: "min-height: 3.5rem;",
            class: "group relative flex items-center gap-2
                    w-full px-4 py-2
                    border #{border} #{bg} #{hover_bg} rounded-lg
                    transition-colors duration-200
                    font-medium shadow-sm leading-none
                    overflow-hidden" do
      event = event.decorate if event.respond_to?(:decorate)

      display_name = truncate_at ? truncate(event.name.to_s, length: truncate_at) : event.name.to_s

      name = content_tag(
        :span,
        display_name,
        title: event.name.to_s,
        class: "font-semibold #{text} truncate"
      )

      subtitle_tag = if subtitle.present?
        content_tag(:span, subtitle, class: "text-xs text-gray-500 font-normal truncate")
      else
        "".html_safe
      end

      text_block = content_tag(
        :div,
        name + subtitle_tag,
        class: "flex flex-col leading-tight text-left min-w-0"
      )

      text_block
    end
  end
end
