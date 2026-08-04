module ContinuingEducationRegistrationsHelper
  # One source of truth for where a CE registration form (new or edit) returns to —
  # the eyebrow, Cancel, and the controller's post-save/create/destroy redirects all
  # agree. Reached from the registrants roster (return_to=registrants) it lands back
  # on that registrant's row (scroll + highlight); from the CE sign-in report
  # (return_to=attendance) on the report's totals table; from the admin CE index
  # (return_to=ce_index) on that index; any other origin falls back to the
  # registration's own edit page.
  def ce_registration_return_path(registration)
    case params[:return_to]
    when "ce_index" then continuing_education_registrations_path
    when "registrants" then registrants_event_row_path(registration.event, registration.id)
    when "attendance" then attendance_event_path(registration.event, ce: "true", anchor: "totals")
    else edit_event_registration_path(registration)
    end
  end

  # Eyebrow label for the CE form back-link, matching whichever origin the form
  # was reached from.
  def ce_registration_return_label
    case params[:return_to]
    when "ce_index" then "CE registrations"
    when "registrants" then "Registrants"
    when "attendance" then "CE sign-in report"
    else "Registration"
    end
  end
end
