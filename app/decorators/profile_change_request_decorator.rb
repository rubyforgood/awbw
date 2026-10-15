class ProfileChangeRequestDecorator < ApplicationDecorator
  AFFILIATION_CHANGE_CHOICES = {
    ProfileChangeRequest::AFFILIATION_CHANGE_TITLE => { label: "Change my title or role", icon: "fa-solid fa-id-badge" },
    ProfileChangeRequest::AFFILIATION_CHANGE_DATES => { label: "Fix my start or end date", icon: "fa-solid fa-calendar-days" },
    ProfileChangeRequest::AFFILIATION_CHANGE_ORGANIZATION => { label: "Fix the organization's name", icon: "fa-solid fa-building" },
    ProfileChangeRequest::AFFILIATION_CHANGE_REMOVE => { label: "I don't work with them anymore", icon: "fa-solid fa-door-open" },
    ProfileChangeRequest::AFFILIATION_CHANGE_WORK_ADDRESS => { label: "Add my work address", icon: "fa-solid fa-location-dot" },
    ProfileChangeRequest::AFFILIATION_CHANGE_OTHER => { label: "Something else", icon: "fa-solid fa-comment" },
    ProfileChangeRequest::AFFILIATION_CHANGE_ADD => { label: "Add an organization", icon: "fa-solid fa-plus" }
  }.freeze

  def heading
    return "Request a profile data change" if other?
    return "Request a license change" if license?

    AFFILIATION_CHANGE_CHOICES.dig(requested_value, :label) if field == "affiliation"
  end

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

  # One plain line the requester recognizes their request by, e.g.
  # "Primary email: new@example.com" or "Title or role: Riverside Center".
  def requester_summary
    parts = if field == "affiliation"
      [ requested_value, (affiliation&.organization || organization)&.name || proposed_organization_name ]
    else
      [ field_label, requested_value.presence || details&.truncate(60) ]
    end
    parts.compact_blank.join(": ")
  end

  def pending_tooltip
    "Change requested #{requested_on} — #{requester_summary}"
  end

  # Back to the card on the owner's edit page the request was started from.
  def profile_return_path
    anchor = if field == "affiliation" then "affiliations"
    elsif field.in?(ProfileChangeRequest::EMAIL_FIELDS) then "emails"
    elsif license? then "professional-licenses"
    end
    h.edit_person_path(person, anchor: anchor)
  end

  # Confirmation prompt for "Approve", spelling out the blast radius where the
  # change reaches beyond this one person (renaming a shared organization).
  def approve_confirm
    case field
    when "primary_email"
      "Approve and send a confirmation email to #{requested_value}?"
    when "secondary_email"
      "Approve and change the secondary email to #{requested_value}?"
    when "organization_name"
      org_rename_confirm(target_organization, requested_value)
    when "affiliation"
      affiliation_approve_confirm
    else
      "Approve and apply this change now?"
    end
  end

  def affiliation_approve_confirm
    case requested_value
    when ProfileChangeRequest::AFFILIATION_CHANGE_ORGANIZATION
      org_rename_confirm(affiliation&.organization, proposed_organization_name)
    when ProfileChangeRequest::AFFILIATION_CHANGE_REMOVE
      "End-date and mark this affiliation inactive?"
    when ProfileChangeRequest::AFFILIATION_CHANGE_ADD
      "Add this affiliation to the profile?"
    else
      "Approve and apply this change now?"
    end
  end

  def org_rename_confirm(org, new_name)
    count = org ? org.affiliations.count : 0
    "Rename \"#{org&.name}\" to \"#{new_name}\"? #{helpers.pluralize(count, "affiliation")} across the portal use this organization."
  end

  # Where "Update manually" sends an admin to make the edit by hand.
  def manual_edit_path
    case field
    when "primary_email"
      person.user ? h.edit_user_path(person.user) : h.edit_person_path(person)
    when "secondary_email", ProfileChangeRequest::OTHER_FIELD
      h.edit_person_path(person)
    when ProfileChangeRequest::LICENSE_FIELD
      professional_license ? h.edit_professional_license_path(professional_license, return_to: "person") : h.edit_person_path(person, anchor: "professional-licenses")
    when "organization_name"
      person.primary_organization ? h.edit_organization_path(person.primary_organization) : h.edit_person_path(person, anchor: "affiliations")
    else
      anchor = affiliation ? h.dom_id(affiliation) : "affiliations"
      h.edit_person_path(person, anchor: anchor)
    end
  end
end
