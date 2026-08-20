module EventRegistrationsHelper
  # Wraps a locked edit-form section in a disabled <fieldset> so its inputs can't be
  # changed or submitted, dimming it as a visual cue. Out-links (Edit scholarship,
  # View allocations…) stay clickable — a <fieldset disabled> only disables form
  # controls, not anchors — so an admin can still reach those flows (with a warning
  # on arrival). When not locked, yields the content untouched. (issue #1944)
  def locked_fieldset(locked, &block)
    content = capture(&block)
    return content unless locked
    content_tag(:fieldset, content, disabled: true, class: "min-w-0 border-0 p-0 m-0 opacity-60")
  end
end
