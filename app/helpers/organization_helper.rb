module OrganizationHelper
  def organization_profile_button(organization, truncate_at: nil, subtitle: nil, label: nil, data: {}, inactive: false, tint: nil, compact: false)
    # Compact mode shrinks the control to roughly a text input's height, for use
    # inline beside form fields (e.g. the affiliation editor rows).
    padding = compact ? "px-3 py-1" : "px-4 py-2"
    avatar_size = compact ? "w-8 h-8" : "w-10 h-10"
    initial_text_size = compact ? "text-sm" : "text-lg"

    if inactive
      bg = "bg-gray-100"
      hover_bg = "hover:bg-gray-200"
      text = "text-gray-400"
      border = "border-gray-300"
    elsif tint == :facilitator
      bg = "bg-purple-100"
      hover_bg = "hover:bg-purple-200"
      text = DomainTheme.text_class_for(:organizations)
      border = "border-purple-300"
    elsif tint == :muted
      bg = "bg-white"
      hover_bg = "hover:bg-gray-50"
      text = DomainTheme.text_class_for(:organizations)
      border = "border-gray-300"
    else
      bg = DomainTheme.bg_class_for(:organizations, intensity: 100)
      hover_bg = DomainTheme.bg_class_for(:organizations, intensity: 100, hover: true)
      text = DomainTheme.text_class_for(:organizations)
      border = DomainTheme.border_class_for(:organizations)
    end
    shadow = tint ? "shadow-none" : "shadow-sm"

    hover_title = [ organization.name, subtitle ].compact_blank.join(" — ")

    link_to organization_path(organization),
            data: { turbo_prefetch: false }.merge(data),
            title: hover_title,
            class: "group relative flex items-center gap-2
                    w-full #{padding}
                    border #{border} #{bg} #{hover_bg} rounded-lg
                    transition-colors duration-200
                    font-medium #{shadow} leading-none
                    overflow-hidden" do
      # --- Logo ---
      logo = if organization.respond_to?(:logo) && organization.logo.attached?
        image_tag organization.logo,
                  class: "#{avatar_size} rounded-full object-cover border border-gray-300 shadow-sm flex-shrink-0"
      else
        content_tag(:span, organization.name.first.upcase,
                    class: "#{avatar_size} rounded-full flex items-center justify-center
                            bg-emerald-200 text-emerald-700 font-bold #{initial_text_size}
                            border border-emerald-300 shadow-sm flex-shrink-0")
      end

      display_name = truncate_at ? truncate(organization.name.to_s, length: truncate_at) : organization.name.to_s

      name = content_tag(
        :span,
        display_name,
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

      label_tag = if label.present?
        content_tag(:span, label,
                    class: "absolute top-1 right-1 px-1.5 py-0.5 rounded text-2xs font-semibold bg-gray-200 text-gray-600")
      else
        "".html_safe
      end

      label_tag + logo + text_block
    end
  end
end
