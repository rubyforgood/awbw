# Decides whether an event registration is "event ready" (the pre-event checklist
# an admin clears before the training) and "completed" (the post-event checklist
# that closes it out), returning the specific failing reasons so the registrants
# roster can render a badge with an explanatory tooltip and the index can filter
# on either state.
#
# Reads only already-loaded associations (organizations, registrant.affiliations,
# allocations, scholarships) so it adds no per-row queries when the roster
# preloads them.
class EventRegistrationReadiness
  # `submitted_org_name` is the organization the registrant typed on the
  # registration form (the `agency_name` answer). It's passed in because resolving
  # it is a batch query the roster already runs once for every row.
  def initialize(registration, submitted_org_name: nil)
    @registration = registration
    @submitted_org_name = submitted_org_name.to_s.strip
  end

  STATUS_LABELS = {
    not_ready: "Not ready",
    ready: "Ready",
    certificate_due: "Certificate pending",
    completed: "Completed"
  }.freeze

  def event_ready?
    event_ready_issues.empty?
  end

  # All post-event work done AND the certificate(s) sent.
  def completed?
    completion_issues.empty?
  end

  # All post-event work done (attended, scholarship tasks met) — i.e. the only
  # thing left is sending the certificate(s). This is the admin's "send a
  # certificate" queue.
  def certifiable?
    completion_work_issues.empty?
  end

  # The registration's single lifecycle state for the roster's one Status column
  # and its matching filter. Completion is the final state and wins; otherwise an
  # outstanding pre-event to-do means "not ready"; a registrant who finished the
  # post-event work but still needs a certificate is "certificate due"; and a
  # clear pre-event checklist with nothing further done is "ready".
  def status
    return :completed if completed?
    return :not_ready unless event_ready?
    return :certificate_due if certifiable?
    :ready
  end

  def status_label
    STATUS_LABELS.fetch(status)
  end

  # The outstanding items relevant to the current status, for the badge tooltip.
  def status_issues
    case status
    when :not_ready then event_ready_issues
    when :certificate_due then certificate_issues
    else []
    end
  end

  # The short reason shown under the badge for the current status: a two-word
  # pre-event reason when not ready, or which certificate(s) are outstanding when
  # certificate-pending. Nil for the ready/completed states.
  def status_reason
    case status
    when :not_ready then event_ready_reason
    when :certificate_due then certificate_due_reason
    end
  end

  # Which certificate(s) still need sending, abbreviated for the badge subtext.
  def certificate_due_reason
    reg_due = !registration_certificate_sent?
    ce_due = ce_certificate_pending?
    return "Reg + CE" if reg_due && ce_due
    return "CE" if ce_due
    "Registration" if reg_due
  end

  # Each pre-event check, in priority order: [ predicate, two-word reason (shown
  # under a "Not ready" badge), full description (tooltip) ]. One table keeps the
  # short and long forms in sync.
  EVENT_READY_CHECKS = [
    [ :payment_due?, "Payment due", "Payment due" ],
    [ :organization_unlinked?, "Org validation", "Organization not linked" ],
    [ :missing_facilitator_affiliation?, "Org validation", "Not a facilitator at a linked organization" ],
    [ :scholarship_uncreated?, "No scholarship", "Scholarship not created" ],
    [ :scholarship_tasks_incomplete?, "Tasks incomplete", "Scholarship tasks incomplete" ],
    [ :ce_unpaid?, "CE unpaid", "CE not paid" ],
    [ :ce_license_missing?, "No license #", "CE license number missing" ]
  ].freeze

  def event_ready_issues
    @event_ready_issues ||= failed_event_ready_checks.map { |_, _, full| full }
  end

  # The two-word reason for the highest-priority outstanding pre-event item,
  # shown under the "Not ready" badge. Nil when nothing is outstanding.
  def event_ready_reason
    failed_event_ready_checks.first&.fetch(1)
  end

  def completion_issues
    completion_work_issues + certificate_issues
  end

  # Post-event work that must happen before a certificate can be issued.
  def completion_work_issues
    @completion_work_issues ||= [].tap do |issues|
      issues << attendance_issue if attendance_issue
      issues << "Scholarship tasks incomplete" if scholarship_tasks_incomplete?
    end
  end

  # The certificate(s) that still need sending once the work above is done.
  def certificate_issues
    @certificate_issues ||= [].tap do |issues|
      issues << "Certificate not sent" unless registration_certificate_sent?
      issues << "CE certificate not sent" if ce_certificate_pending?
    end
  end

  private

  attr_reader :registration, :submitted_org_name

  def failed_event_ready_checks
    @failed_event_ready_checks ||= EVENT_READY_CHECKS.select { |predicate, _, _| send(predicate) }
  end

  def payment_due?
    registration.event.cost_cents.to_i > 0 && !registration.paid_in_full?
  end

  # Flags a registrant who typed an organization on the form but has none linked.
  # Once an admin links any organization they've made the call, so a non-matching
  # submitted name is not treated as outstanding.
  def organization_unlinked?
    submitted_org_name.present? && registration.organizations.empty?
  end

  # A registrant linked to an organization is expected to hold an active
  # Facilitator affiliation with it. Flags when any linked org lacks one.
  def missing_facilitator_affiliation?
    registration.organizations.any? do |org|
      registration.registrant.affiliations.none? do |affiliation|
        affiliation.organization_id == org.id && affiliation.facilitator? && affiliation.active?
      end
    end
  end

  def scholarship_uncreated?
    registration.scholarship_requested? && !registration.scholarship?
  end

  def scholarship_tasks_incomplete?
    registration.scholarship? && !registration.scholarship_tasks_met?
  end

  def ce_unpaid?
    registration.ce_credit_requested? && !ce_paid?
  end

  def ce_license_missing?
    registration.ce_credit_requested? && !registration.ce_license_provided?
  end

  def ce_certificate_pending?
    registration.ce_credit_requested? && !ce_certificate_sent?
  end

  # Post-event criteria are only met by a full "attended". "incomplete_attendance"
  # explicitly does not satisfy them; everything else means they never showed.
  def attendance_issue
    return nil if registration.attended?
    registration.status == "incomplete_attendance" ? "Attendance incomplete" : "Did not attend"
  end

  # The admin-created CE billing records for this registration (preloaded on the
  # roster). Their payment + certificate state drives the CE readiness checks.
  def ce_registrations
    registration.continuing_education_registrations
  end

  # CE is paid once every CE registration is paid in full. A requested-but-not-yet
  # -created CE registration counts as unpaid (nothing to pay against yet).
  def ce_paid?
    ce_registrations.any? && ce_registrations.all?(&:paid_in_full?)
  end

  # The registration's own completion certificate (certificate_sent_at, via
  # Registerable#certificate_sent?).
  def registration_certificate_sent?
    registration.certificate_sent?
  end

  # CE certificates are sent once every CE registration's certificate has been
  # sent. No CE registration yet means nothing has been issued.
  def ce_certificate_sent?
    ce_registrations.any? && ce_registrations.all?(&:certificate_sent?)
  end
end
