module FormsHelper
  # Sibling-page subnav shared across a form's Results / Submissions / View /
  # Edit / Edit sections pages so each reads like a set of tabs linking to the
  # others. `current` renders the active page as plain text instead of a link;
  # pass `:none` to keep every tab clickable.
  def form_page_subnav(form, current:, event: nil)
    submissions_return = current == :results ? "form_results" : "forms"
    tabs = [
      form_subnav_tab("Results", results_form_path(form), active: current == :results),
      form_subnav_tab("Submissions", form_submissions_path(form_id: form.id, return_to: submissions_return), active: current == :submissions),
      form_subnav_tab("View", form_path(form), active: current == :view),
      form_subnav_tab("Edit", edit_form_path(form, event_id: event&.id), active: current == :edit),
      form_subnav_tab("Edit sections", edit_sections_form_path(form, event_id: event&.id), active: current == :edit_sections)
    ]
    content_tag :nav, safe_join(tabs), aria: { label: "Form pages" },
      class: "inline-flex flex-wrap items-center gap-0.5 rounded-lg border #{DomainTheme.border_class_for(:forms, intensity: 200)} #{DomainTheme.bg_class_for(:forms)} p-0.5"
  end

  def form_subnav_tab(label, path, active:, **link_opts)
    return content_tag(:span, label, aria: { current: "page" },
      class: "rounded-md bg-white px-2.5 py-1 text-sm font-semibold shadow-sm #{DomainTheme.text_class_for(:forms, intensity: 700)}") if active

    link_to label, path,
      class: "rounded-md px-2.5 py-1 text-sm #{DomainTheme.text_class_for(:forms, intensity: 700)} #{DomainTheme.bg_class_for(:forms, hover: true)}", **link_opts
  end

  # "Duplicate form" action button, shown beneath the subnav on the View and
  # Edit pages. Makes a full copy of the form (route stays `copy`); nil when the
  # admin can't copy this form.
  def form_duplicate_button(form)
    return unless allowed_to?(:copy?, form)

    link_to copy_form_path(form),
      class: button_classes(:secondary_outline, size: :sm, extra: "inline-flex items-center gap-1.5 whitespace-nowrap"),
      data: { turbo_method: :post, turbo_confirm: %(Make a full duplicate of "#{form.display_name}"?) } do
      safe_join([ content_tag(:i, "", class: "fa-solid fa-clone"), "Duplicate form" ])
    end
  end

  # The live public registration page for this form, shown on the editor pages.
  # Only available when we know the event the admin came from — the preview
  # (the subnav's "View") can't fill header tokens or run conditional logic
  # without an event.
  def form_live_view_link(event)
    return unless event

    link_to "Live form", new_event_public_registration_path(event),
      class: "text-sm #{eyebrow_link_class} px-2 py-1"
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
