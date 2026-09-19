class ProfileChangeRequestDecorator < ApplicationDecorator
  def status_badge
    classes, icon, label = case status
    when "resolved" then [ "bg-green-50 text-green-800 border-green-300", "fa-solid fa-circle-check", "Resolved" ]
    when "declined" then [ "bg-red-50 text-red-800 border-red-300", "fa-solid fa-circle-xmark", "Declined" ]
    else [ "bg-amber-50 text-amber-800 border-amber-300", "fa-solid fa-clock", "Pending" ]
    end
    h.render "shared/badge", label: label, classes: classes, icon: icon
  end

  # A short note on how a resolved request was closed.
  def resolution_note
    return unless resolved?
    resolution_method == "approved" ? "Auto-applied" : "Resolved manually"
  end

  def requested_on
    created_at.strftime("%b %-d, %Y")
  end

  # Where "Update manually" sends an admin to make the edit by hand.
  def manual_edit_path
    case field
    when "primary_email"
      person.user ? h.edit_user_path(person.user) : h.edit_person_path(person)
    when "organization_name"
      person.primary_organization ? h.edit_organization_path(person.primary_organization) : h.edit_person_path(person, anchor: "affiliations")
    else
      h.edit_person_path(person, anchor: "affiliations")
    end
  end
end
