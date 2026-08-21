module FormsHelper
  # The form editor's top-right links. The standalone "Preview form" is always
  # available. When we also know which event the admin came from, we add a
  # "View form" link to the real public-facing registration page — the preview
  # can't fill header tokens or run conditional logic without an event.
  def form_editor_view_links(form, event)
    link_class = "text-sm text-gray-500 hover:text-gray-700 px-2 py-1"
    preview = link_to "Preview", form_path(form), class: link_class
    return preview unless event

    view = link_to "View", new_event_public_registration_path(event), class: link_class
    safe_join([ view, preview ])
  end

  # Human-readable role for a form: "Registration", "Bulk Payment", etc.,
  # falling back to "General" when no role is set.
  def form_role_label(form)
    form.role.presence&.titleize || "General"
  end

  OTHER_RESPONSES_PHRASE = "Other responses review queue"

  # Renders a smart field's plain-text effect with the "Other responses review
  # queue" phrase turned into a link to that page. The effect strings stay plain
  # prose (testable, no markup); the link is woven in here at render time.
  def smart_field_effect(effect)
    return effect unless effect.include?(OTHER_RESPONSES_PHRASE)

    link = link_to OTHER_RESPONSES_PHRASE, other_responses_path,
      class: "text-purple-600 hover:text-purple-800 underline", target: "_blank", rel: "noopener"
    safe_join(effect.split(OTHER_RESPONSES_PHRASE, -1), link)
  end
end
