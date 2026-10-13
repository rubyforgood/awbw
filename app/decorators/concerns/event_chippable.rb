# Shared "event chip" for feed rows (comments and communications): a small pill
# naming the event a row is about, shown before the subject/topic. Includers
# supply `event` (the Event, or nil) and `event_chip_record` (the attached
# record a registration is resolved from).
module EventChippable
  # The EventRegistration the chip links to. A scholarship is unwrapped once to
  # its allocated record (an event registration or a CE registration); nothing
  # nests deeper than that. nil when none is resolvable.
  def event_registration
    record = event_chip_record
    record = record.allocation&.allocatable if record.is_a?(Scholarship)
    case record
    when EventRegistration then record
    when ContinuingEducationRegistration then record.event_registration
    end
  end

  # Compact chip naming the event: the abbreviation, or the title with its date.
  # Links to the registration's edit page when `linked:` is set and one is
  # resolvable; a plain span otherwise — safe inside a row that is itself a link.
  def event_chip(linked: false, **options)
    return "" unless event

    chip_class = "inline-flex shrink-0 items-center rounded #{DomainTheme.bg_class_for(:events, intensity: 100)} px-1.5 py-0.5 text-xs font-medium #{DomainTheme.text_class_for(:events, intensity: 800)}"
    label = event.decorate.chip_label
    registration = event_registration if linked

    if registration
      h.link_to(label, h.edit_event_registration_path(registration), title: event.title,
                data: { turbo_frame: "_top" }, class: "#{chip_class} hover:underline", **options)
    else
      h.content_tag(:span, label, { class: chip_class, title: event.title }.merge(options))
    end
  end
end
