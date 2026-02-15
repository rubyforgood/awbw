module OrganizationHelper
  def organization_profile_button(organization, truncate_at: nil, subtitle: nil, label: nil)
    bg = DomainTheme.bg_class_for(:organizations, intensity: 100)
    hover_bg = DomainTheme.bg_class_for(:organizations, intensity: 100, hover: true)
    text = DomainTheme.text_class_for(:organizations)
    border = DomainTheme.border_class_for(:organizations)

    link_to organization_path(organization),
            class: "group relative flex items-center gap-2
                    w-full px-4 py-2
                    border #{border} #{bg} #{hover_bg} rounded-lg
                    transition-colors duration-200
                    font-medium shadow-sm leading-none
                    overflow-hidden" do
      # --- Logo ---
      logo = if organization.respond_to?(:logo) && organization.logo.attached?
        image_tag url_for(organization.logo),
                  class: "w-10 h-10 rounded-full object-cover border border-gray-300 shadow-sm flex-shrink-0"
      else
        content_tag(:span, organization.name.first.upcase,
                    class: "w-10 h-10 rounded-full flex items-center justify-center
                            bg-emerald-200 text-emerald-700 font-bold text-lg
                            border border-emerald-300 shadow-sm flex-shrink-0")
      end

      display_name = truncate_at ? truncate(organization.name.to_s, length: truncate_at) : organization.name.to_s

      name = content_tag(
        :span,
        display_name,
        title: organization.name.to_s,
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
                    class: "absolute top-1 right-1 px-1.5 py-0.5 rounded text-[10px] font-semibold bg-gray-200 text-gray-600")
      else
        "".html_safe
      end

      label_tag + logo + text_block
    end
  end
end
