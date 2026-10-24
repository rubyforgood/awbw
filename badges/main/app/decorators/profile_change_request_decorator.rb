class ProfileChangeRequestDecorator < ApplicationDecorator
  AFFILIATION_CHANGE_CHOICES = {
    ProfileChangeRequest::AFFILIATION_CHANGE_TITLE => { label: "Change my title or role", icon: "fa-solid fa-id-badge" },
    ProfileChangeRequest::AFFILIATION_CHANGE_DATES => { label: "Fix my start or end date", icon: "fa-solid fa-calendar-days" },
    ProfileChangeRequest::AFFILIATION_CHANGE_ORGANIZATION => { label: "Fix the organization's name", icon: "fa-solid fa-building" },
    ProfileChangeRequest::AFFILIATION_CHANGE_REMOVE => { label: "I don't work with them anymore", icon: "fa-solid fa-door-open" },
    ProfileChangeRequest::AFFILIATION_CHANGE_UPDATE_WORK_ADDRESS => { label: "Change my work address", icon: "fa-solid fa-map-location-dot" },
    ProfileChangeRequest::AFFILIATION_CHANGE_WORK_ADDRESS => { label: "Add my work address", icon: "fa-solid fa-location-dot" },
    ProfileChangeRequest::AFFILIATION_CHANGE_OTHER => { label: "Something else", icon: "fa-solid fa-comment" },
    ProfileChangeRequest::AFFILIATION_CHANGE_ADD => { label: "Add an organization", icon: "fa-solid fa-plus" }
  }.freeze
  CLOSE_PROGRAM_CHOICE = { label: "Close my AWBW program here", icon: "fa-solid fa-door-closed" }.freeze
  PENDING_AFFILIATION_LABELS = {
    ProfileChangeRequest::AFFILIATION_CHANGE_TITLE => "New title or role",
    ProfileChangeRequest::AFFILIATION_CHANGE_DATES => "New start or end date",
    ProfileChangeRequest::AFFILIATION_CHANGE_ORGANIZATION => "Fix organization name",
    ProfileChangeRequest::AFFILIATION_CHANGE_REMOVE => "Leave organization",
    ProfileChangeRequest::AFFILIATION_CHANGE_UPDATE_WORK_ADDRESS => "New work address",
    ProfileChangeRequest::AFFILIATION_CHANGE_WORK_ADDRESS => "Add work address",
    ProfileChangeRequest::AFFILIATION_CHANGE_ADD => "Add organization"
  }.freeze

  # Leaving a Facilitator role closes the program there, so it reads that way.
  def self.affiliation_change_choices(affiliation)
    choices = AFFILIATION_CHANGE_CHOICES.except(ProfileChangeRequest::AFFILIATION_CHANGE_ADD)
    affiliation&.facilitator? ? choices.merge(ProfileChangeRequest::AFFILIATION_CHANGE_REMOVE => CLOSE_PROGRAM_CHOICE) : choices
  end

  def heading
    return "Request a profile data change" if other?
    return "Request a license change" if license?
    return CLOSE_PROGRAM_CHOICE[:label] if closing_program?

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
    elsif email?
      [ field_label, PersonDecorator.email_with_type(requested_value, proposed_email_type) ]
    else
      [ field_label, requested_value.presence || details&.truncate(60) ]
    end
    parts.compact_blank.join(": ")
  end

  # The requester's own pending request in plain words, e.g.
  # "Leave organization: Riverside Center" or "New primary email: new@example.com".
  def pending_summary
    label, value = if field == "affiliation"
      [ pending_affiliation_label, (affiliation&.organization || organization)&.name || proposed_organization_name ]
    elsif email?
      [ "New #{field_label.downcase}", PersonDecorator.email_with_type(requested_value, proposed_email_type) ]
    else
      [ field_label, requested_value.presence || details&.truncate(60) ]
    end
    [ label, value ].compact_blank.join(": ")
  end

  def pending_affiliation_label
    return "Close AWBW program" if closing_program?

    PENDING_AFFILIATION_LABELS.fetch(requested_value, "Organization change")
  end

  def current_display
    email? ? PersonDecorator.email_with_type(current_value, current_email_type) : current_value
  end

  def requested_display
    email? ? PersonDecorator.email_with_type(requested_value, proposed_email_type) : requested_value
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

  # Every review action emails the requester, so each prompt says who gets it.
  def approve_confirm
    with_email_notice(approve_change_confirm)
  end

  def resolve_confirm
    with_email_notice("Mark this request as resolved?")
  end

  def decline_confirm
    with_email_notice("Decline this request?")
  end

  def review_outcome
    return "declined" if declined?
    resolution_method == "approved" ? "approved" : "resolved"
  end

  def email_greeting
    name = requested_by&.person&.first_name.presence || requested_by&.first_name.presence
    name ? "Dear #{name}," : "Hello,"
  end

  def requested_change
    from = previous_value ? " from #{previous_value}" : ""
    case field
    when *ProfileChangeRequest::EMAIL_FIELDS then "change your #{field_label.downcase}#{from} to #{requested_display}"
    when "organization_name" then "change your organization name#{from} to #{requested_value}"
    when "affiliation" then affiliation_requested_change
    else "update your #{field_label.downcase}"
    end
  end

  # The live value is the old one only while the change is unapplied: Devise keeps
  # the old login until the new address is confirmed, and a decline changes nothing.
  def previous_value
    return unless field == "primary_email" || declined?

    value = current_display
    value if value.present? && value != requested_display
  end

  def affiliation_requested_change
    org = (affiliation&.organization || organization)&.name || proposed_organization_name
    with_org = org ? " with #{org}" : ""
    at_org = org ? " at #{org}" : ""
    case requested_value
    when ProfileChangeRequest::AFFILIATION_CHANGE_ADD then "add an affiliation#{with_org}"
    when ProfileChangeRequest::AFFILIATION_CHANGE_REMOVE then closing_program? ? "close your AWBW program#{at_org}" : "end your affiliation#{with_org}"
    when ProfileChangeRequest::AFFILIATION_CHANGE_ORGANIZATION then "change your organization's name to #{proposed_organization_name}"
    when ProfileChangeRequest::AFFILIATION_CHANGE_TITLE then "change your title or role#{at_org} to #{proposed_title}"
    when ProfileChangeRequest::AFFILIATION_CHANGE_DATES then "change your start or end dates#{at_org}"
    else "update your affiliation#{with_org}"
    end
  end

  def review_email_recipient
    email = requested_by&.email
    "#{requested_by.full_name} <#{email}>" if email.present?
  end

  # Spells out the blast radius where the change reaches beyond this one person
  # (renaming a shared organization).
  def approve_change_confirm
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
      closing_program? ? "Close the program at #{affiliation.organization&.name}? #{close_program_summary}." : "End-date and mark this affiliation inactive?"
    when ProfileChangeRequest::AFFILIATION_CHANGE_ADD
      add_affiliation_confirm
    else
      "Approve and apply this change now?"
    end
  end

  def add_affiliation_confirm
    ending = affiliations_ending_elsewhere.size
    return "Add this affiliation to the profile?" if ending.zero?

    "Add this affiliation and end #{helpers.pluralize(ending, "affiliation")} at other organizations?"
  end

  def org_rename_confirm(org, new_name)
    count = org ? org.affiliations.count : 0
    "Rename \"#{org&.name}\" to \"#{new_name}\"? #{helpers.pluralize(count, "affiliation")} across the portal use this organization."
  end

  def with_email_notice(prompt)
    email = requested_by&.email
    return prompt if email.blank?

    "#{prompt} This emails #{requested_by.full_name} (#{email}), including your note."
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
