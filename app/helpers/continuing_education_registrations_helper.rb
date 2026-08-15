module ContinuingEducationRegistrationsHelper
  # One source of truth for where a CE registration form (new or edit) returns to —
  # the eyebrow, Cancel, and the controller's post-save/create/destroy redirects all
  # agree. Reached from the registrants roster (return_to=registrants) it lands back
  # on that registrant's row (scroll + highlight); any other origin falls back to the
  # registration's own edit page.
  def ce_registration_return_path(registration)
    return continuing_education_registrations_path if params[:return_to] == "ce_index"
    return registrants_event_row_path(registration.event, registration.id) if params[:return_to] == "registrants"
    edit_event_registration_path(registration)
  end

  # Eyebrow label for the CE form back-link, matching whichever origin the form
  # was reached from.
  def ce_registration_return_label
    case params[:return_to]
    when "ce_index" then "CE registrations"
    when "registrants" then "Registrants"
    else "Registration"
    end
  end
end
