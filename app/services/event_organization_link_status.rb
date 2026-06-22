# Classifies an event's registrations by how their organization is resolved,
# mirroring the badge logic in `events/_registrants_results` so the registrants
# filter and the displayed pills agree:
#
# - linked:  the registration has at least one linked organization
# - pending: the registrant submitted an agency name that doesn't match any
#            linked organization (needs admin attention)
# - none:    no linked organization and no submitted agency name
#
# The states are not mutually exclusive — a registration can be both linked and
# pending — so each option returns everyone matching that predicate.
class EventOrganizationLinkStatus
  STATUSES = %w[linked pending none].freeze

  def initialize(event)
    @event = event
  end

  # Registration ids matching the given status ("linked"/"pending"/"none").
  # Returns [] for an unrecognized status so callers can scope to nothing.
  def registration_ids_for(status)
    case status.to_s
    when "linked" then linked_registration_ids
    when "pending" then pending_registration_ids
    when "none" then none_registration_ids
    else []
    end
  end

  private

  attr_reader :event

  def linked_registration_ids
    registrations.select { |registration| linked_names(registration).present? }.map(&:id)
  end

  def pending_registration_ids
    registrations.select { |registration| needs_linking?(registration) }.map(&:id)
  end

  def none_registration_ids
    registrations.select do |registration|
      linked_names(registration).blank? && submitted_name(registration).blank?
    end.map(&:id)
  end

  def needs_linking?(registration)
    name = submitted_name(registration)
    name.present? && linked_names(registration).exclude?(name.downcase)
  end

  def linked_names(registration)
    linked_names_by_registration.fetch(registration.id, [])
  end

  def submitted_name(registration)
    submitted_names_by_registrant[registration.registrant_id].to_s.strip
  end

  def registrations
    @registrations ||= event.event_registrations.pluck(:id, :registrant_id)
      .map { |id, registrant_id| Registration.new(id, registrant_id) }
  end

  # Linked organization names (lowercased) keyed by registration id.
  def linked_names_by_registration
    @linked_names_by_registration ||= EventRegistrationOrganization
      .joins(:organization)
      .where(event_registration_id: registrations.map(&:id))
      .pluck(:event_registration_id, Arel.sql("organizations.name"))
      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(registration_id, name), memo|
        memo[registration_id] << name.to_s.strip.downcase
      end
  end

  # Agency name submitted on the registration form, keyed by registrant (person) id.
  def submitted_names_by_registrant
    return @submitted_names_by_registrant if defined?(@submitted_names_by_registrant)
    form = event.registration_form
    field = form&.form_fields&.find_by(field_identifier: "agency_name")
    @submitted_names_by_registrant = if field
      FormAnswer.joins(:form_submission)
        .where(form_submissions: { person_id: registrations.map(&:registrant_id), form_id: form.id }, form_field_id: field.id)
        .pluck(Arel.sql("form_submissions.person_id"), :submitted_answer)
        .to_h
    else
      {}
    end
  end

  Registration = Struct.new(:id, :registrant_id)
end
