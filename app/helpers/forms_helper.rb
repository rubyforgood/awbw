module FormsHelper
  # Placeholder that names an input and its length limit, e.g. "Option text (255 char max)".
  def max_length_placeholder(label, max)
    "#{label} (#{number_with_delimiter(max)} char max)"
  end

  # Sibling-page subnav shared across a form's Results / Submissions / Preview /
  # Edit / Edit sections pages so each reads like a set of tabs linking to the
  # others. `current` renders the active page as plain text instead of a link;
  # pass `:none` to keep every tab clickable.
  def form_page_subnav(form, current:, event: nil)
    submissions_return = current == :results ? "form_results" : "forms"
    tabs = [
      form_subnav_tab("Results", results_form_path(form), active: current == :results),
      form_subnav_tab("Submissions", form_submissions_path(form_id: form.id, return_to: submissions_return), active: current == :submissions),
      form_subnav_tab("Preview", form_path(form), active: current == :view),
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

  # Which submissions the rollup covers. The empty state reads these to tell a
  # filtered-to-nothing view apart from a form nobody has filled in.
  def form_results_filter_params
    {
      event_id: @selected_event_id,
      organization_id: @selected_organization_id,
      start_date: @selected_start_date,
      end_date: @selected_end_date
    }.compact
  end

  # Everything a link out of a results card must carry to land back on the same
  # view: those filters plus the question search, renamed because the answers
  # list spends `question` on the one card that was drilled into.
  def form_results_link_params
    form_results_filter_params.merge(results_question: @selected_question).compact
  end

  # Stable anchor for a question's card on the results page, so a page reached
  # from that card can scroll back to exactly the card it opened. A fanned-out
  # copy's card adds its wording. Mirrors FormSubmissionsHelper#form_submission_row_id.
  def form_results_card_id(field_id, question = nil)
    "form-question-#{[ field_id, question.to_s.parameterize.presence ].compact.join("-")}"
  end

  # The same state read back off a page the results linked to, for its eyebrow —
  # including which card was opened, so the return lands on it rather than at the
  # top of the rollup.
  def form_results_return_params(params)
    {
      event_id: params[:event_id].presence,
      organization_id: params[:organization_id].presence,
      start_date: params[:start_date].presence,
      end_date: params[:end_date].presence,
      question: params[:results_question].presence,
      anchor: form_results_return_anchor(params)
    }.compact
  end

  # The card a drill-down came from: a fanned-out copy's while the question box
  # still holds one of its wordings, otherwise the field's own card.
  def form_results_return_anchor(params)
    return if params[:form_field_id].blank?

    field = FormField.find_by(id: params[:form_field_id])
    form_results_card_id(params[:form_field_id], (params[:question] if field&.per_resource_wording?(params[:question])))
  end

  # A results card's footer link to the Form submissions list: the submissions
  # that answered this question, narrowed like the rollup. form_field_id plus the
  # question's wording both filter that list and name the card for its eyebrow to
  # return to.
  def form_results_submissions_params(form, report)
    {
      form_id: form.id,
      form_field_id: report.field.id,
      question: report.label,
      return_to: "form_results",
      **form_results_link_params
    }.compact
  end

  # A results card's drill-down into the Form answers list: this question, on
  # this form, narrowed exactly like the rollup the admin is looking at, plus the
  # origin that gives that list an eyebrow back here. `form_field_id` pins the
  # exact question — the name alone is a LIKE search there, which would also
  # match a sibling question whose name contains this one's.
  def form_results_drilldown_params(form, report)
    {
      form_id: form.id,
      question: report.label,
      form_field_id: report.field&.id,
      return_to: "form_results",
      **form_results_link_params
    }.compact
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
