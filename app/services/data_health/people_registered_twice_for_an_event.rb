module DataHealth
  # One person holding more than one registration for the same event — an inactive
  # (cancelled / no-show / transferred-out) one beside a newer one, as an import
  # creates rather than overwrite a deliberate status. Listed once per person and
  # event; the registrations deduper folds them together when they're the same seat.
  class PeopleRegisteredTwiceForAnEvent < Check
    def title = "People registered more than once for an event"

    def explanation
      "A person can keep a cancelled, no-show, or transferred-out registration beside a newer one for " \
      "the same event (a spreadsheet import adds one rather than overwrite that status). Keep both when " \
      "they're a real history, or merge them in the registrations deduper."
    end

    def scope
      EventRegistration.where(id: first_registration_ids).includes(:registrant, :event)
    end

    def describe(registration)
      statuses = EventRegistration.where(registrant_id: registration.registrant_id, event_id: registration.event_id)
        .order(:id).map(&:attendance_status_label)
      "#{registration.registrant&.name} — #{registration.event&.title} (#{statuses.join(", ")})"
    end

    def path_for(registration) = dedupe_index_event_registrations_path(event_id: registration.event_id)

    def review_path = dedupe_index_event_registrations_path

    def review_label = "Dedupe registrations"

    private

    def first_registration_ids
      EventRegistration.group(:registrant_id, :event_id).having("COUNT(*) > 1").select("MIN(event_registrations.id)")
    end
  end
end
