module EventHelper
  # Splits an ActionText rich text into two HTML-safe fragments by character length.
  # Splits at the nearest block-element boundary after `split_length` plain-text characters.
  # Returns [top_html, bottom_html].
  def split_rich_text(rich_text, split_length: 400)
    return ["".html_safe, "".html_safe] if rich_text.blank?

    # Access the raw body HTML (no ActionText layout wrappers)
    html = rich_text.body&.to_html.to_s
    return ["".html_safe, "".html_safe] if html.blank?

    doc = Nokogiri::HTML.fragment(html)
    children = doc.element_children

    # If no block elements (plain text content), return everything as top
    return [html.html_safe, "".html_safe] if children.empty?

    char_count = 0
    split_index = children.length # default: everything in top

    children.each_with_index do |node, i|
      char_count += node.text.length
      if char_count >= split_length
        split_index = i + 1
        break
      end
    end

    top_nodes = children.first(split_index)
    bottom_nodes = children.drop(split_index)

    top_html = top_nodes.map(&:to_html).join.html_safe
    bottom_html = bottom_nodes.map(&:to_html).join.html_safe

    [top_html, bottom_html]
  end

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
