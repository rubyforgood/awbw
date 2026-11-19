module AllocationsHelper
  # A consistent, polymorphic descriptor for whatever an allocation points at, so
  # the allocations index reads the same for any allocatable type and links
  # through to the record when a route exists. Add a `when` clause for each new
  # allocatable type; everything else falls back to a name + humanized type.
  # `return_params` (e.g. from a bulk payment tray) are appended to a linkable
  # path so the destination's back link can return to the origin.
  def allocatable_descriptor(allocatable, return_params: {})
    case allocatable
    when EventRegistration
      {
        path: edit_event_registration_path(allocatable, return_params),
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

  # Hover text for the who/when icon on each allocation row: who created it,
  # plus who last changed it when it was touched after creation.
  def allocation_audit_title(allocation)
    lines = [ "Created #{allocation_audit_stamp(allocation.created_at, allocation.created_by)}" ]
    if allocation.updated_at.present? && allocation.updated_at != allocation.created_at
      lines << "Updated #{allocation_audit_stamp(allocation.updated_at, allocation.updated_by)}"
    end
    lines.join("\n")
  end

  private

  def allocation_audit_stamp(time, user)
    who = user ? (person_name(user).presence || user.email) : "unknown"
    "#{time&.strftime("%b %-d, %Y at %-l:%M %p")} by #{who}"
  end
end
