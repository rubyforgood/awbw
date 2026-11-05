module EventRegistrationsHelper
  LOCKED_SECTION_NOTE = "These are no longer editable for transferred out registrations.".freeze

  # Wraps a locked edit-form section in a disabled <fieldset> so its inputs can't be
  # changed or submitted, dimming it as a visual cue. Out-links (Edit scholarship,
  # View allocations…) stay clickable — a <fieldset disabled> only disables form
  # controls, not anchors — so an admin can still reach those flows (with a warning
  # on arrival). When not locked, yields the content untouched. (issue #1944)
  # wrapper_class places a locked section in a parent grid, e.g. its column span.
  def locked_fieldset(locked, wrapper_class: nil, &block)
    content = capture(&block)
    return content unless locked

    # Grid keeps cards in a row equal height; the lock sits outside the fieldset to stay undimmed.
    fieldset = content_tag(:fieldset, content, disabled: true, class: "grid min-w-0 grid-cols-1 space-y-6 border-0 p-0 opacity-60")
    lock = content_tag(:span, tag.i(class: "fa-solid fa-lock"),
                       title: LOCKED_SECTION_NOTE, role: "img", aria: { label: LOCKED_SECTION_NOTE },
                       class: "absolute -right-2 -top-2 flex h-6 w-6 cursor-help items-center justify-center rounded-full border border-purple-200 bg-purple-50 text-xs text-purple-600")
    content_tag(:div, fieldset + lock, class: [ "relative grid", wrapper_class ])
  end
end
