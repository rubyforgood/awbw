module OrganizationHelper
  def organization_profile_button(organization, truncate_at: nil)
    bg = DomainTheme.bg_class_for(:organizations, intensity: 100)
    hover_bg = DomainTheme.bg_class_for(:organizations, intensity: 100, hover: true)
    text = DomainTheme.text_class_for(:organizations)
    border = DomainTheme.border_class_for(:organizations)

    link_to organization_path(organization),
            class: "group flex items-center gap-2
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

      text_block = content_tag(
        :div,
        name,
        class: "flex flex-col leading-tight text-left min-w-0"
      )

      logo + text_block
    end
  end
end
