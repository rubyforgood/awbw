# One-off: link the TAC261 event's (#19) unlinked registrations to an organization,
# the same way an admin linking by hand does. Gathers every organization FileMaker and
# the portal tie each registrant to (the Q45 Blazer query's sources) and links only when
# the choice is clear, in this order:
#
#   1. the organization on their FileMaker TAC261 row,
#   2. the one candidate matching the organization name they typed on the portal form,
#   3. the one organization every current source agrees on.
#
# Everyone else is listed with their candidates and where each came from, for staff to
# link by hand. FileMaker organizations with no portal match are listed by name and code.
#
# Dry run by default: does everything, prints it, rolls back.
#
#   bin/rails runner scripts/link_march_2026_registrations_from_affiliations.rb
#   DRY_RUN=false bin/rails runner scripts/link_march_2026_registrations_from_affiliations.rb

dry_run = ENV["DRY_RUN"] != "false"

event = Event.find(19)
TAC261_FM_EVENT_IDS = %w[E3977 E3979 E3980].freeze
FREE_EMAIL_DOMAINS = %w[gmail.com yahoo.com hotmail.com outlook.com icloud.com aol.com comcast.net me.com live.com msn.com].freeze
Candidate = Struct.new(:organization, :fm_org_id, :fm_org_name, :source, :current, keyword_init: true)

import_user = Setting.import_user
abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

Current.user = import_user
Current.source = OrganizationServices::LinkSubmittedOrganization::CHANGE_SOURCE

org_name_field = event.registration_form&.form_fields&.find_by(field_identifier: "organization_name")
typed_names = if org_name_field
  FormAnswer.answered.joins(:form_submission)
    .where(form_field_id: org_name_field.id, form_submissions: { event_id: event.id })
    .order(:created_at)
    .pluck("form_submissions.person_id", :submitted_answer)
    .to_h
else
  {}
end

normalize = ->(name) { name.to_s.squish.downcase }

fm_candidate = lambda do |fm_org_id, source, fm_org_text = nil|
  fm_org_id = fm_org_id.to_s.strip.presence
  next if fm_org_id.nil? && fm_org_text.blank?

  organizations = fm_org_id ? Organization.with_filemaker_code(fm_org_id).to_a : []
  fm_org_name = fm_org_id && FmOrganization.find_by(fm_id: fm_org_id)&.data&.dig("OrgName")
  fm_org_name ||= fm_org_text
  next Candidate.new(fm_org_id:, fm_org_name:, source:, current: true) if organizations.empty?

  organizations.map { |organization| Candidate.new(organization:, fm_org_id:, fm_org_name:, source:, current: true) }
end

candidates_for = lambda do |person|
  codes = person.filemaker_codes
  rows = []

  if codes.any?
    FmParticipant.find_by_data("EventID", TAC261_FM_EVENT_IDS).find_by_data("ParticipantID", codes).each do |row|
      rows << fm_candidate.(row.data["OrgID"], "FileMaker TAC261 row", row.data["Organization"])
    end
    FmRolodex.where(fm_id: codes).each do |row|
      rows << fm_candidate.(row.data["OrgID"], "FileMaker contact record", row.data["Organization"])
    end
    FmPeopleToOrganization.find_by_data("PersonID", codes).each do |row|
      rows << fm_candidate.(row.data["OrgID"], "FileMaker person-to-organization link")
    end
    FmPersonnel.find_by_data("PersonID", codes).each do |row|
      project = FmProject.find_by(fm_id: row.data["ProjectID"])
      rows << fm_candidate.(project&.data&.dig("OrgID"), "FileMaker personnel: #{project&.data&.dig("ProjectName") || row.data["ProjectID"]}")
    end
    FmFormSubmission.find_by_data("RolodexID", codes).each do |row|
      rows << fm_candidate.(row.data["OrgID"], "FileMaker form: #{row.data["FormTitle"]}")
    end
    FmPayment.find_by_data("RolodexID", codes).each do |row|
      rows << fm_candidate.(row.data["OrgID"], "FileMaker payment")
    end
  end

  person.affiliations.each do |affiliation|
    current = !affiliation.inactive? && (affiliation.end_date.nil? || affiliation.end_date >= Date.current)
    label = "portal affiliation: #{affiliation.title.presence || "untitled"}#{" (ended)" unless current}"
    rows << Candidate.new(organization: affiliation.organization, source: label, current:)
  end

  domain = person.email.to_s.split("@").last.to_s.downcase
  if domain.present? && FREE_EMAIL_DOMAINS.exclude?(domain)
    Organization.where("LOWER(website_url) LIKE :web OR LOWER(email) LIKE :email", web: "%#{domain}%", email: "%@#{domain}").each do |organization|
      rows << Candidate.new(organization:, source: "portal org matching email domain #{domain}", current: true)
    end
  end

  rows.flatten.compact
end

unlinked = event.event_registrations.active
  .organization_linking_status("unlinked", event)
  .includes(registrant: { affiliations: :organization })
  .to_a

linked = []
manual = []

ActiveRecord::Base.transaction(requires_new: true) do
  unlinked.each do |registration|
    person = registration.registrant
    candidates = candidates_for.(person)
    typed = typed_names[person.id]
    matched = candidates.select(&:organization)

    tac261 = matched.select { |candidate| candidate.source == "FileMaker TAC261 row" }.map(&:organization).uniq
    by_typed = typed.present? ? matched.map(&:organization).uniq.select { |org| normalize.(org.name) == normalize.(typed) } : []
    current = matched.select(&:current).map(&:organization).uniq

    choice, reason = if tac261.one? then [ tac261.first, "FileMaker TAC261 row" ]
    elsif by_typed.one? then [ by_typed.first, "matches typed name" ]
    elsif current.one? then [ current.first, "only current candidate" ]
    end

    unless choice
      manual << [ registration, candidates, typed ]
      next
    end

    registration.event_registration_organizations.find_or_create_by!(organization: choice)
    OrganizationServices::LinkSubmittedOrganization.call(
      person: person,
      organization: choice,
      entry: nil,
      scenario: event.linking_scenario,
      training_date: event.starts_on,
      event_registration: registration
    )
    linked << [ registration, choice, reason, typed ]
  end

  Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
  raise ActiveRecord::Rollback if dry_run
end

describe = ->(registration) { "reg ##{registration.id} ##{registration.registrant_id} #{registration.registrant.full_name}" }

puts "#{event.title} (##{event.id}): #{unlinked.size} unlinked active registrations"
puts
puts "LINKED (#{linked.size})"
linked.each do |registration, organization, reason, typed|
  line = "  #{describe.(registration)} → ##{organization.id} #{organization.name} [#{reason}]"
  line += "  (typed: #{typed})" if typed.present? && normalize.(typed) != normalize.(organization.name)
  puts line
end

puts
puts "LINK BY HAND (#{manual.size})"
manual.each do |registration, candidates, typed|
  puts "  #{describe.(registration)}"
  puts "    typed: #{typed}" if typed.present?
  puts "    no candidates" if candidates.empty?
  candidates.group_by { |candidate| [ candidate.organization, candidate.fm_org_id ] }.each do |(organization, fm_org_id), group|
    name = organization ? "##{organization.id} #{organization.name}" : "not in portal: #{group.first.fm_org_name} (FileMaker #{fm_org_id || "no code"})"
    puts "    #{name} — #{group.map(&:source).uniq.join("; ")}"
  end
end

puts
puts dry_run ? "DRY RUN — rolled back, nothing written. Set DRY_RUN=false to apply." : "Done. Check ##{event.id}'s registrants."
