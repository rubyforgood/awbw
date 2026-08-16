module EventsHelper
  # Stable anchor id for a registrant's row on the Onboarding matrix, so back-links
  # from detail pages can scroll to (and highlight) the row they came from.
  def onboarding_row_id(record_or_id)
    id = record_or_id.respond_to?(:id) ? record_or_id.id : record_or_id
    "onboarding-row-#{id}"
  end

  # Path back to a specific registrant's row on the Onboarding matrix (scrolls to
  # and highlights it). Accepts an Event or event id, and a registration id.
  def onboarding_event_row_path(event_or_id, registration_id)
    onboarding_event_path(event_or_id, anchor: onboarding_row_id(registration_id), highlight: registration_id)
  end

  # Stable anchor id for a registrant's row on the Registrants roster, so back
  # links (e.g. from a viewed submission) can scroll to and highlight it.
  def registrant_row_id(record_or_id)
    id = record_or_id.respond_to?(:id) ? record_or_id.id : record_or_id
    "registrant-row-#{id}"
  end

  # Path back to a specific registrant's row on the Registrants roster (scrolls
  # to and highlights it). Accepts an Event or event id, and a registration id.
  def registrants_event_row_path(event_or_id, registration_id)
    registrants_event_path(event_or_id, anchor: registrant_row_id(registration_id), highlight: registration_id)
  end

  # Path back to one recipient's card on the Scholarship recipients page, where the
  # cards are anchored by registration slug (`participant-<slug>`, with a scroll-mt
  # so the sticky header doesn't cover them). Shared by every page reached from
  # there — the registration and scholarship edit pages and their post-save
  # redirects — so the anchor is built once. A blank slug lands at the top.
  def recipients_event_card_path(event, participant_slug)
    recipients_event_path(event, anchor: ("participant-#{participant_slug}" if participant_slug.present?))
  end

  # Where a revenue figure drills in. The money lives on registrations, so these
  # land on a registrations table with payment columns rather than the attendees
  # people-index — matching the per-registrant breakdown rows lower down the same
  # report. Scoped to one event that's its Manage list; across events it's the
  # registrations index, which takes the same filters.
  def revenue_drilldown_path(filters)
    event_id = params[:event_id].presence
    return registrants_event_path(event_id, **filters.except(:event_year)) if event_id
    event_registrations_path(**filters)
  end

  # Human label for the attendees index's population filters — e.g.
  # "Attended · All trainings". Shown in the page subtitle so the defaults the page
  # applies are visible rather than implied.
  def attendee_population_label(attendance_status, event_type)
    outcome = EventRegistration::ATTENDANCE_FILTER_OPTIONS.rassoc(attendance_status)&.first || "All outcomes"
    type = EventRegistration::EVENT_TYPE_FILTER_OPTIONS.rassoc(event_type)&.first || "All events"
    "#{outcome} · #{type}"
  end

  # The scholarships report's filter/toggle state, carried through a drill-in so
  # its eyebrow can rebuild the exact view (period, event type/id, search, funder,
  # split/combined layout, and the report's own origin) the user came from.
  REPORT_FILTER_KEYS = %i[ time_period event_type event_id search funder_sgid view return_to ].freeze

  # Stable anchor id for a training's row on the scholarships report, so the
  # registrants eyebrow can scroll to and highlight the row drilled in from.
  def training_report_row_id(event_or_id)
    id = event_or_id.respond_to?(:id) ? event_or_id.id : event_or_id
    "training-row-#{id}"
  end

  # Forward: from a scholarships report row into that training's *attended*
  # registrants, stamped so the roster's eyebrow returns to the exact row
  # (highlight + anchor) with the report's filters/toggle restored.
  def attended_registrants_path(event)
    registrants_event_path(event,
      attendance_status: "attended",
      return_to: "scholarships",
      return_highlight: event.id,
      return_anchor: training_report_row_id(event),
      report_filters: params.permit(*REPORT_FILTER_KEYS).to_h.compact_blank)
  end

  # Forward: from a scholarships report row's expanded recipient list into that
  # recipient's registration for the training, stamped like #attended_registrants_path
  # so the roster's eyebrow returns to the exact row (highlight + anchor) with the
  # report's filters/toggle restored.
  def scholarship_recipient_registrants_path(event, recipient)
    registrants_event_path(event,
      registrant_ids: recipient.id,
      return_to: "scholarships",
      return_highlight: event.id,
      return_anchor: training_report_row_id(event),
      report_filters: params.permit(*REPORT_FILTER_KEYS).to_h.compact_blank)
  end

  # Back: the registrants eyebrow's path to the scholarships report, restoring the
  # carried filters/toggle and highlighting the row the user drilled in from.
  def scholarships_report_return_path
    filters = params.fetch(:report_filters, ActionController::Parameters.new).permit(*REPORT_FILTER_KEYS)
    scholarships_events_path(**filters.to_h.symbolize_keys,
      highlight: params[:return_highlight].presence,
      anchor: params[:return_anchor].presence)
  end

  # Header for any "Program status" column. A program status is only meaningful
  # relative to a date, so the header names the event it was judged at — "Program
  # status (TOS205)" — and the caveat below covers the case where there is none.
  def program_status_column_label(event = nil)
    return "Program status" if event.blank?

    "Program status (#{event.decorate.compact_label})"
  end

  # The hover note for a Program status column: which date the verdicts were
  # judged on. Cross-event lists have no event date to anchor on, so they read as
  # of the start of the current year (see FacilitatorProgramStatus).
  def program_status_column_note(event = nil)
    return "New / Ongoing / Reinstate as of #{event.start_date.strftime('%b %-d, %Y')}, this event's start date." if event&.start_date

    "No single event in view, so each organization reads as of #{Date.current.beginning_of_year.strftime('%b %-d, %Y')} — the start of the current reporting year."
  end

  # Ordered column descriptors for the event Onboarding matrix. The array index
  # is the table-sort column index, so the header row and every body row iterate
  # this same list — keeping header buttons and cell positions aligned no matter
  # which optional columns (payment, attendance days) are present.
  def onboarding_columns(event)
    columns = [ { key: "edit", label: "Edit", kind: :edit, sortable: false, align: "center", sticky: true } ]
    columns += [
      { key: "first_name", label: "First", kind: :first_name, sortable: true, align: "left" },
      { key: "last_name", label: "Last", kind: :last_name, sortable: true, align: "left" }
    ]
    (1..event.day_count).each do |day|
      columns << { key: "completed_day_#{day}", label: "Day #{day}", kind: :checkbox, field: "completed_day_#{day}", sortable: true, align: "center", toggle: "days" }
    end
    columns << { key: "attendance", label: "Event attendance", kind: :attendance, sortable: true, align: "center", toggle: "attendance" }
    columns += [
      { key: "program", label: "Organization", kind: :program, sortable: true, align: "left", toggle: "program" },
      { key: "program_type", label: program_status_column_label(event), kind: :program_type, sortable: true, align: "center", toggle: "program_type", note: program_status_column_note(event) }
    ]
    if event.cost_cents.to_i > 0
      columns << { key: "payment", label: "Payment", kind: :payment, sortable: true, align: "center", toggle: "payment" }
      columns << { key: "fees_due", label: "Fees due", kind: :fees_due, sortable: true, align: "center", toggle: "fees_due" }
      columns << { key: "paid", label: "Paid amount", kind: :paid, sortable: true, align: "center", toggle: "paid" }
    end
    columns << { key: "discounted", label: "Discounted amount", kind: :discounted, sortable: true, align: "center", toggle: "discounted" }
    columns << { key: "scholarship_amount", label: "Scholarship amount", kind: :scholarship_amount, sortable: true, align: "center", toggle: "scholarship_amount" }
    columns << { key: "funder", label: "Scholarship grant", kind: :funder, sortable: true, align: "left", toggle: "funder" }
    columns << { key: "scholarship_tasks_completed", label: "Scholarship tasks done", kind: :scholarship_tasks, sortable: true, align: "center", toggle: "scholarship_tasks_completed" }
    if event.ce_eligible?
      columns << { key: "ce_hours", label: "CE hours", kind: :ce_hours, sortable: true, align: "center", toggle: "ce_hours" }
      columns << { key: "ce_amount", label: "CE amount", kind: :ce_amount, sortable: true, align: "center", toggle: "ce_amount" }
      columns << { key: "ce_license", label: "License #", kind: :ce_license, sortable: true, align: "center", toggle: "ce_license" }
    end
    columns << { key: "fee_note", label: "Fee note", kind: :fee_note, sortable: false, align: "center", toggle: "fee_note" }
    columns << { key: "portal_invite", label: "Portal invite", kind: :portal_invite, sortable: true, align: "center", toggle: "portal_invite" }
    EventRegistration::CHECKLIST_STEPS.each do |step, label|
      columns << { key: step, label: label, kind: :checkbox, field: step, sortable: true, align: "center", toggle: step }
    end
    columns << { key: "flagged_comments", label: "Flagged comments", kind: :flagged_comments, sortable: true, align: "center", toggle: "flagged_comments" }
    columns << { key: "comments", label: "Comments", kind: :comments, sortable: true, align: "left", toggle: "comments" }
    columns << { key: "email", label: "Email", kind: :email, sortable: true, align: "left" }
    columns
  end

  # Columns minus any the admin has hidden (by their toggle key). Non-toggleable
  # columns (edit, name, email, progress) are always kept.
  def visible_onboarding_columns(event, hidden_columns = [])
    onboarding_columns(event).reject { |column| column[:toggle].present? && hidden_columns.include?(column[:toggle]) }
  end

  # Distinct column show/hide menu entries (label keyed by toggle key),
  # collapsing the per-day columns into a single "Attendance days" toggle.
  def onboarding_toggle_entries(event)
    onboarding_columns(event).each_with_object({}) do |column, entries|
      attr = column[:toggle]
      next if attr.blank? || entries.key?(attr)

      entries[attr] = attr == "days" ? "Attendance days" : column[:label]
    end
  end

  # The reports hub and the full revenue/participation reports share the
  # event-type and specific-event filters directly, but express the time window
  # differently: the hub's `period` select offers this_year/last_year/all_time,
  # while the reports use `time_period` where a specific window is the calendar
  # year "YYYY". These helpers translate a page's active filters into the query
  # params for its cross-link so filters carry across — and back — between the
  # summaries' "Full report" links and the reports' "← Reports" eyebrow.

  # Reports hub filters → full report query params.
  def hub_to_report_params
    {
      return_to: params[:return_to],
      event_type: params[:event_type].presence,
      event_id: params[:event_id].presence,
      time_period: hub_period_to_time_period(@period)
    }.compact
  end

  # Reports hub filters → attendees index query params, plus the reports origin so
  # the index's eyebrow comes back here. The index defaults its event-type filter
  # to facilitator trainings, so a hub scoped to an event of any other type would
  # drill in to an empty list — when one event is the scope it already answers the
  # question the event-type filter asks, so pin that filter open.
  def hub_to_attendees_params(extra = {})
    attendees_params = hub_to_report_params.merge(return_to: "reports")
    attendees_params[:event_type] ||= EventRegistration::FILTER_ALL if attendees_params[:event_id].present?
    attendees_params[:event_year] = time_period_to_event_year(attendees_params.delete(:time_period))
    attendees_params.compact.merge(extra)
  end

  # Full report filters → reports hub query params.
  def report_to_hub_params
    {
      return_to: params[:return_to],
      event_type: params[:event_type].presence,
      event_id: params[:event_id].presence,
      period: time_period_to_hub_period(@time_period)
    }.compact
  end

  # Report time_period → the attendees index's `event_year` filter. The index has
  # no time_period vocabulary of its own — it narrows by the event's calendar year
  # (the same translation the participation card's figure links already do) — so
  # passing time_period through would silently drop the period. "all_time" is nil,
  # which leaves the year filter open.
  def time_period_to_event_year(time_period)
    return Date.current.year.to_s if time_period == "this_year"
    time_period if Integer(time_period, exception: false)
  end

  # Filter params the report sub-nav carries between angles, so switching from the
  # figures to the people behind them (or to their logged time) never silently widens
  # the population. Each destination reads the ones it knows and ignores the rest:
  # the report pages and the attendees index share event_id/event_type but keep their
  # own vocabularies for period (the reports narrow by time_period, the index by the
  # event's calendar year) and funding source (funder_sgid names a specific funder;
  # funder is grant-funded vs org-subsidized).
  REPORT_SUBNAV_PARAMS = %i[
    event_id event_type search funder_sgid time_period view registrant_ids
    attendance_status payment_status funder scholarship
    sector contact_info affiliation_status organization_id org_city state county
    age_group life_experience setting country school_district program_status
  ].freeze

  # Those of the above that are actually set, ready to merge into a sub-nav link.
  def report_subnav_params
    params.permit(*REPORT_SUBNAV_PARAMS).to_h.symbolize_keys.compact_blank
  end

  # How many events the sign-ins header names before trailing off — enough to read
  # the scope at a glance without running the header onto three lines.
  SIGNINS_LABEL_LIMIT = 6

  # What the cross-event sign-ins page is scoped to, for the header's event slot.
  # With no filter applied it reads "All events"; a narrowed set names its events by
  # abbreviation (falling back to the title), so the scope is legible without counting
  # the sections below. The single-event case never reaches here — the header's own
  # `event:` slot renders that one linked to the event.
  def signins_scope_label(events, narrowed:)
    return "All events" unless narrowed && events.present?

    labels = events.map { |event| event.decorate.compact_label }
    shown = labels.first(SIGNINS_LABEL_LIMIT).join(", ")
    labels.size > SIGNINS_LABEL_LIMIT ? "#{shown} +#{labels.size - SIGNINS_LABEL_LIMIT} more" : shown
  end

  # "last_year" becomes the prior calendar year (reports name specific years
  # "YYYY"); this_year/all_time pass through unchanged.
  def hub_period_to_time_period(period)
    return (Date.current.year - 1).to_s if period == "last_year"
    period
  end

  # Inverse: the prior year maps back to "last_year", the current year to
  # "this_year"; any other specific year has no hub equivalent, so fall back to
  # "all_time".
  def time_period_to_hub_period(time_period)
    case time_period
    when "this_year", "all_time" then time_period
    when (Date.current.year - 1).to_s then "last_year"
    when Date.current.year.to_s then "this_year"
    else "all_time"
    end
  end
end
