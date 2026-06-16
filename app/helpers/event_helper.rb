module EventHelper
  # The "please specify" placeholder for an option label, or nil when the option
  # does not reveal a free-text box. Canonical config lives on FormField (shared
  # with answer validation).
  def specify_placeholder(label)
    FormField.specify_placeholder_for(label)
  end

  # True when a stored answer selects the given specify option: the bare label,
  # or its "<label>: <text>" form. Works for single (string) and multi (array)
  # answers.
  def specify_option_selected?(label, value)
    Array(value).any? { |v| v.to_s == label.to_s || v.to_s.start_with?("#{label}:") }
  end

  # Extracts the user's typed text from a stored "<label>: <text>" answer for the
  # given specify option, or "" when the option is bare or unselected.
  def specify_option_text(label, value)
    answer = Array(value).find { |v| v.to_s == label.to_s || v.to_s.start_with?("#{label}:") }
    answer.to_s.delete_prefix(label.to_s).delete_prefix(":").strip
  end

  # Splits an ActionText rich text into two HTML-safe fragments by character length.
  # Splits at the nearest block-element boundary after `split_length` plain-text characters.
  # Returns [top_html, bottom_html].
  def split_rich_text(rich_text, split_length: 400)
    return [ "".html_safe, "".html_safe ] if rich_text.blank?

    # Access the raw body HTML (no ActionText layout wrappers)
    html = rich_text.body&.to_html.to_s
    return [ "".html_safe, "".html_safe ] if html.blank?

    doc = Nokogiri::HTML.fragment(html)
    children = doc.element_children

    # If no block elements (plain text content), return everything as top
    return [ html.html_safe, "".html_safe ] if children.empty?

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

    [ top_html, bottom_html ]
  end

  # Back link for any page reached from a bulk payment tray (the expanded card on
  # the bulk payments index). Returns to that index re-expanding the originating
  # submission's row and anchor-scrolling to it. Relies on the originating link
  # passing `expand: submission.id`; the card reads `params[:expand]` to expand and
  # carries a matching `id="payment-card-<id>"` + `scroll-mt-*` for the anchor.
  def bulk_payments_return_path(event)
    expand = params[:expand].presence
    bulk_payments_event_path(
      event,
      expand: expand,
      anchor: ("payment-card-#{expand}" if expand)
    )
  end

  def event_profile_button(event, truncate_at: nil, subtitle: nil, data: {}, path: nil)
    bg = DomainTheme.bg_class_for(:events, intensity: 100)
    hover_bg = DomainTheme.bg_class_for(:events, intensity: 100, hover: true)
    text = DomainTheme.text_class_for(:events)
    border = DomainTheme.border_class_for(:events)

    link_to path || event_path(event),
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

  def display_response_text(field, response)
    text = resolve_answer_text(field, response&.submitted_answer)
    return tag.span("—", class: "text-gray-400") if text.blank?
    text
  end

  # Resolve a stored answer to readable text, mapping the sector/category ids
  # behind the professional fields to their names. Free-text tokens (e.g. an
  # "Other: <text>" answer) aren't ids, so they pass through unchanged. Returns
  # nil for a blank answer (unlike display_response_text, which renders a
  # placeholder), so it suits inline header values on the scholarship page.
  def resolve_answer_text(field, submitted_answer)
    return if submitted_answer.blank?

    tokens = submitted_answer.split(", ")
    resolve = ->(klass) {
      tokens.filter_map { |token| klass.find_by(id: token)&.name || (token unless token.match?(/\A\d+\z/)) }
            .join(", ").presence || submitted_answer
    }
    case field&.field_identifier
    when "primary_service_area", "primary_service_area_single"
      resolve.call(Sector)
    when "workshop_environments", "client_life_experiences", "primary_age_group"
      resolve.call(Category)
    else
      submitted_answer
    end
  end
end
