module OrganizationHelper
  # Color mapping for an organization's AWBW program status, mirroring the event
  # background dashboard (app/views/events/background.html.erb).
  PROGRAM_STATUS_STYLES = {
    new: "bg-green-100 text-green-700 border-green-200",
    ongoing: "bg-blue-100 text-blue-700 border-blue-200",
    reinstated: "bg-amber-100 text-amber-700 border-amber-200"
  }.freeze

  # Compact single-letter badge (N / O / R) for an organization's program
  # status, with the full label as a tooltip. Accepts either a :new/:ongoing/
  # :reinstated symbol (EventDashboard / index controller) or the "New"/"Ongoing"/
  # "Reinstate" string from Organization#program_status. Returns nil when blank or
  # unrecognized.
  def program_status_badge(status)
    return if status.blank?

    normalized = status.to_s.downcase
    key = normalized.start_with?("reinstat") ? :reinstated : normalized.to_sym
    classes = PROGRAM_STATUS_STYLES[key]
    return unless classes

    content_tag(:span, normalized.first.upcase,
                title: key.to_s.titleize,
                class: "inline-flex shrink-0 items-center justify-center w-5 h-5 rounded-full border text-xs font-semibold #{classes}")
  end

  def organization_profile_button(organization, truncate_at: nil, subtitle: nil, label: nil, data: {}, inactive: false)
    if inactive
      bg = "bg-gray-100"
      hover_bg = "hover:bg-gray-200"
      text = "text-gray-400"
      border = "border-gray-300"
    else
      bg = DomainTheme.bg_class_for(:organizations, intensity: 100)
      hover_bg = DomainTheme.bg_class_for(:organizations, intensity: 100, hover: true)
      text = DomainTheme.text_class_for(:organizations)
      border = DomainTheme.border_class_for(:organizations)
    end

    hover_title = [ organization.name, subtitle ].compact_blank.join(" — ")

    link_to organization_path(organization),
            data: { turbo_prefetch: false }.merge(data),
            title: hover_title,
            class: "group relative flex items-center gap-2
                    w-full px-4 py-2
                    border #{border} #{bg} #{hover_bg} rounded-lg
                    transition-colors duration-200
                    font-medium shadow-sm leading-none
                    overflow-hidden" do
      # --- Logo ---
      logo = if organization.respond_to?(:logo) && organization.logo.attached?
        image_tag organization.logo,
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
