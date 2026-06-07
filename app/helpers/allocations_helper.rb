module AllocationsHelper
  # A consistent, polymorphic descriptor for whatever an allocation points at, so
  # the allocations index reads the same for any allocatable type and links
  # through to the record when a route exists. Add a `when` clause for each new
  # allocatable type; everything else falls back to a name + humanized type.
  def allocatable_descriptor(allocatable)
    case allocatable
    when EventRegistration
      {
        path: edit_event_registration_path(allocatable),
        title: "Event registration for #{allocatable.registrant&.full_name}",
        subtitle: allocatable.event&.title
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
