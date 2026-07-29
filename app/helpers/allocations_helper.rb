module AllocationsHelper
  # A consistent, polymorphic descriptor for whatever an allocation points at, so
  # the allocations index reads the same for any allocatable type and links
  # through to the record when a route exists. Add a `when` clause for each new
  # allocatable type; everything else falls back to a name + humanized type.
  # `return_params` (e.g. from a bulk payment tray) are appended to a linkable
  # path so the destination's back link can return to the origin.
  # compact: drop the "Event registration for" framing and the event subtitle —
  # used where the surrounding context (e.g. a bulk payment ticket) already makes
  # the event and that it's a registration obvious, so only the registrant matters.
  def allocatable_descriptor(allocatable, return_params: {}, compact: false)
    case allocatable
    when EventRegistration
      {
        path: edit_event_registration_path(allocatable, return_params),
        title: compact ? allocatable.registrant&.full_name : "Event registration for #{allocatable.registrant&.full_name}",
        subtitle: compact ? nil : allocatable.event&.title
      }
    else
      {
        path: allocatable_link_path(allocatable),
        title: allocatable.try(:name) || allocatable.try(:title) || allocatable.model_name.human,
        subtitle: allocatable.model_name.human
      }
    end
  end

  # Best-effort link to an allocatable; nil when the model has no route so the
  # caller renders a non-clickable label instead.
  def allocatable_link_path(allocatable)
    polymorphic_path(allocatable)
  rescue NoMethodError, ActionController::UrlGenerationError
    nil
  end
end
