module ContinuingEducationRegistrationsHelper
  # One source of truth for where a CE registration form (new or edit) returns to —
  # the eyebrow, Cancel, and the controller's post-save/create/destroy redirects all
  # agree. Reached from the registrants roster (return_to=registrants) it lands back
  # on that registrant's row (scroll + highlight); any other origin falls back to the
  # registration's own edit page.
  def ce_registration_return_path(registration)
    return registrants_event_row_path(registration.event, registration.id) if params[:return_to] == "registrants"
    edit_event_registration_path(registration)
  end
end
