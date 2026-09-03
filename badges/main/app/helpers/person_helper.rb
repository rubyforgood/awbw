module PersonHelper
  def person_profile_button(person, truncate_at: nil, subtitle: nil, display_name: nil, data: {}, inactive: false, tint: nil, path_params: {}, width_class: "w-full", compact: false)
    # Compact mode shrinks the whole control (padding, avatar, type) for dense
    # tables like the registrants roster where horizontal space is at a premium.
    padding = compact ? "px-2 py-1" : "px-4 py-2"
    avatar_size = compact ? "w-6 h-6" : "w-10 h-10"
    initial_text_size = compact ? "text-xs" : "text-lg"
    name_text_size = compact ? "text-xs" : ""

    palette = person_button_palette(tint:, inactive:)
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
                    border #{palette[:border]} #{palette[:bg]} #{palette[:hover_bg]} rounded-lg
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
        class: "font-semibold #{name_text_size} #{palette[:text]} truncate"
      )

      text_block = content_tag(
        :div,
        name + person_button_subtitle(subtitle),
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

  # A person card that links to the person's edit page instead of their profile,
  # for admin-facing contexts. No avatar — an uppercase "Edit" tag reads before
  # the name (layout: :prefix, "EDIT Jane Doe" on one line) or stacked above it
  # (layout: :eyebrow). An optional subtitle (e.g. the person's email) renders on
  # its own line below, mirroring person_profile_button. Admin-facing, so it shows
  # the full name — the person's display-name preference (first-name-only, etc.)
  # governs public credits, not what an admin sees here.
  def person_edit_button(person, layout: :prefix, truncate_at: nil, subtitle: nil, display_name: nil, data: {}, inactive: false, tint: nil, path_params: {}, width_class: "w-full", compact: false)
    padding = compact ? "px-2 py-1" : "px-4 py-2"
    name_text_size = compact ? "text-xs" : "text-sm"

    palette = person_button_palette(tint:, inactive:)
    shadow = tint ? "shadow-none" : "shadow-sm"

    full_name = display_name || person.try(:full_name).presence || person.decorate.name.to_s
    full_name = truncate(full_name, length: truncate_at) if truncate_at
    hover_title = [ "Edit", full_name, subtitle ].compact_blank.join(" — ")

    link_to edit_person_path(person, **path_params),
            data: { turbo_prefetch: false }.merge(data),
            title: hover_title,
            class: "group relative flex items-center gap-2
                    #{width_class} #{padding}
                    border #{palette[:border]} #{palette[:bg]} #{palette[:hover_bg]} rounded-lg
                    transition-colors duration-200
                    font-medium #{shadow} leading-none
                    overflow-hidden" do
      eyebrow = content_tag(:span, "Edit", class: "shrink-0 text-2xs text-gray-400 uppercase")
      name = content_tag(:span, full_name, class: "truncate font-semibold #{name_text_size} #{palette[:text]}")
      subtitle_tag = person_button_subtitle(subtitle)

      if layout == :eyebrow
        content_tag(:div, safe_join([ eyebrow, name, subtitle_tag ]), class: "flex flex-col leading-tight text-left min-w-0")
      else
        # Eyebrow to the left of a name/email column so the email reads parallel
        # below the name (not indented under the "Edit" tag).
        name_block = content_tag(:div, safe_join([ name, subtitle_tag ]), class: "flex flex-col leading-tight min-w-0")
        content_tag(:div, safe_join([ eyebrow, name_block ]), class: "flex items-baseline gap-1.5 text-left min-w-0")
      end
    end
  end

  # A compact card button for a user account — the actor behind created_by/
  # updated_by audit credits, which reference a User (not a domain person), so it
  # links to the user's show page. Rendered as a people-themed pill rather than an
  # inline underline. The user show page is admin-only, so non-admin viewers get
  # the plain name instead of a link they couldn't follow.
  def user_button(user, compact: true, data: {})
    name = user.try(:full_name).presence || user.try(:name).presence || user.email
    return content_tag(:span, name, class: "font-medium text-gray-700") unless allowed_to?(:show?, user)

    palette = person_button_palette(tint: nil, inactive: false)
    padding = compact ? "px-2 py-1" : "px-4 py-2"
    name_size = compact ? "text-xs" : "text-sm"

    link_to user_path(user),
            data: { turbo_prefetch: false }.merge(data),
            title: name,
            class: "group inline-flex w-fit items-center gap-1.5 #{padding} rounded-lg border " \
                   "#{palette[:border]} #{palette[:bg]} #{palette[:hover_bg]} font-medium shadow-sm leading-none transition-colors duration-200" do
      content_tag(:span, name, class: "truncate font-semibold #{name_size} #{palette[:text]}")
    end
  end

  # Text-link sibling of user_button for the audit footer. Non-admin viewers, who
  # can't follow the admin-only user show page, get the plain name instead.
  def user_link(user, data: {})
    name = user.try(:full_name).presence || user.try(:name).presence || user.email
    return content_tag(:span, name, class: "font-medium text-gray-700") unless allowed_to?(:show?, user)

    link_to name, user_path(user),
            data: { turbo_prefetch: false }.merge(data),
            class: "font-medium text-indigo-600 hover:text-indigo-800 hover:underline"
  end

  private

  # Shared color palette for the person profile/edit buttons, keyed off the same
  # tint/inactive options both accept.
  def person_button_palette(tint:, inactive:)
    if inactive
      { bg: "bg-gray-100", hover_bg: "hover:bg-gray-200", text: "text-gray-400", border: "border-gray-300" }
    elsif tint == :facilitator
      { bg: "bg-purple-100", hover_bg: "hover:bg-purple-200", text: "text-gray-800", border: "border-purple-300" }
    elsif tint == :facilitator_light
      { bg: "bg-purple-50", hover_bg: "hover:bg-purple-100", text: "text-gray-800", border: "border-purple-200" }
    elsif tint == :nonfac
      { bg: "bg-blue-100", hover_bg: "hover:bg-blue-200", text: "text-gray-800", border: "border-blue-300" }
    elsif tint == :nonfac_light
      { bg: "bg-blue-50", hover_bg: "hover:bg-blue-100", text: "text-gray-800", border: "border-blue-200" }
    elsif tint == :muted
      { bg: "bg-white", hover_bg: "hover:bg-gray-50", text: DomainTheme.text_class_for(:people), border: "border-gray-300" }
    else
      { bg: DomainTheme.bg_class_for(:people, intensity: 100), hover_bg: DomainTheme.bg_class_for(:people, intensity: 100, hover: true), text: DomainTheme.text_class_for(:people), border: DomainTheme.border_class_for(:people) }
    end
  end

  def person_button_subtitle(subtitle)
    return "".html_safe if subtitle.blank?

    "<!--email_off-->".html_safe +
      content_tag(:span, subtitle, class: "text-xs text-gray-500 font-normal truncate") +
      "<!--email_on-->".html_safe
  end
end
