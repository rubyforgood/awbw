# The admin checklist for running an event, derived entirely from system state
# (nothing is manually checkable). Each item is a to-do (outstanding work remains),
# done (satisfied), or not relevant (doesn't apply to this event — e.g. free event,
# no CE, or the event hasn't happened yet), in the order an admin works through the
# event's lifecycle: Set up -> Before the event -> During & after.
#
# Registrant-facing work (payment, CE, scholarship tasks) links to the bulk
# reminder flow pre-filtered to the affected people; admin work (linking orgs,
# allocating bulk payments, sending certificates, reviewing reports) links to the
# roster / Scholarships / bulk-payments / forms / reports pages pre-filtered.
#
# Reuses EventDashboard for every count and registrant list. Not-relevant items
# skip their dashboard queries, so pre-event pages don't compute post-event work.
class EventChecklist
  include Rails.application.routes.url_helpers

  PHASES = %i[ setup before after ].freeze
  PHASE_LABELS = {
    setup: "Set up",
    before: "Before the event",
    after: "During & after the event"
  }.freeze
  PHASE_SHORT = { setup: "Set up", before: "Before", after: "After" }.freeze

  # kind: :task (count-based), :flag (binary done/not-done), :action (a standing
  #   action with no done state, e.g. review reports), :placeholder (not built yet).
  # status: :todo / :done / :not_relevant.
  # A drill row shown when a non-registrant item expands (e.g. bulk-payment
  # submitters): a title, optional subtitle (org), amount, and a link.
  DetailRow = Data.define(:title, :subtitle, :amount_cents, :path)

  Item = Data.define(:key, :phase, :title, :actor, :kind, :status, :count,
                     :money_cents, :detail, :registrants, :detail_rows, :action_path, :action_label) do
    def todo?
      status == :todo
    end

    def done?
      status == :done
    end

    def not_relevant?
      status == :not_relevant
    end

    def registrant_task?
      actor == :registrant
    end

    def trackable?
      kind == :task || kind == :flag
    end
  end

  def initialize(dashboard)
    @dashboard = dashboard
    @event = dashboard.event
  end

  def items
    @items ||= [
      setup_forms, setup_callouts, setup_publish, setup_event_type,
      link_organizations, allocate_bulk_payments, review_flagged_comments,
      collect_registration_fees, issue_scholarships, set_scholarship_funders,
      follow_up_agreements, fix_zero_scholarships, complete_scholarship_tasks,
      collect_ce_licenses, collect_ce_fees, issue_ce_certificates,
      send_pre_event_reminders,
      record_attendance, reconcile_ce_hours, send_completion_certificates,
      review_reports, post_event_survey
    ]
  end

  def todo_items
    items.select(&:todo?)
  end

  def resolved_items
    items.reject(&:todo?)
  end

  def todo_items_by_phase
    todo_items.group_by(&:phase)
  end

  def all_clear?
    todo_items.empty?
  end

  # Progress reflects only trackable (task/flag) items — standing actions and the
  # unbuilt survey placeholder don't have a "done" state.
  def relevant_count
    trackable_items.count { |item| !item.not_relevant? }
  end

  def done_count
    trackable_items.count(&:done?)
  end

  def todo_count
    todo_items.size
  end

  private

  def trackable_items
    items.select(&:trackable?)
  end

  # --- Item builders ---------------------------------------------------------
  def task(key:, phase:, title:, actor:, action_path:, action_label:, relevant:,
           count: 0, registrants: [], detail_rows: [], money_cents: nil, detail: nil)
    status = if !relevant
      :not_relevant
    elsif count.positive?
      :todo
    else
      :done
    end
    Item.new(key: key, phase: phase, title: title, actor: actor, kind: :task,
             status: status, count: count, money_cents: money_cents, detail: detail,
             registrants: registrants, detail_rows: detail_rows,
             action_path: action_path, action_label: action_label)
  end

  def flag(key:, phase:, title:, actor:, action_path:, action_label:, relevant:, done:, detail: nil)
    status = if !relevant
      :not_relevant
    elsif done
      :done
    else
      :todo
    end
    Item.new(key: key, phase: phase, title: title, actor: actor, kind: :flag,
             status: status, count: nil, money_cents: nil, detail: detail,
             registrants: [], detail_rows: [], action_path: action_path, action_label: action_label)
  end

  def action(key:, phase:, title:, actor:, action_path:, action_label:, relevant:, detail: nil)
    Item.new(key: key, phase: phase, title: title, actor: actor, kind: :action,
             status: relevant ? :todo : :not_relevant, count: nil, money_cents: nil,
             detail: detail, registrants: [], detail_rows: [],
             action_path: relevant ? action_path : nil, action_label: action_label)
  end

  def placeholder(key:, phase:, title:, detail:)
    Item.new(key: key, phase: phase, title: title, actor: :admin, kind: :placeholder,
             status: :not_relevant, count: nil, money_cents: nil, detail: detail,
             registrants: [], detail_rows: [], action_path: nil, action_label: nil)
  end

  # --- Set up ----------------------------------------------------------------
  def setup_forms
    flag(key: :setup_forms, phase: :setup, title: "Set up event forms", actor: :admin,
         relevant: true, done: @dashboard.registration_form_ready?,
         action_path: forms_path(event_id: @event.id), action_label: "Edit forms",
         detail: "Registration, CE and scholarship forms")
  end

  def setup_callouts
    flag(key: :setup_callouts, phase: :setup, title: "Review ticket callouts", actor: :admin,
         relevant: true, done: @dashboard.callouts_reviewed?,
         action_path: edit_event_path(@event, expand: "callouts", anchor: "registration_ticket_callouts"),
         action_label: "Edit", detail: "Detected from edits to the defaults")
  end

  def setup_publish
    flag(key: :setup_publish, phase: :setup, title: "Publish the event page", actor: :admin,
         relevant: true, done: @dashboard.event_page_published?,
         action_path: edit_event_path(@event), action_label: "Edit")
  end

  def setup_event_type
    flag(key: :setup_event_type, phase: :setup, title: "Mark the event type", actor: :admin,
         relevant: true, done: @dashboard.event_type_marked?,
         action_path: edit_event_path(@event), action_label: "Edit",
         detail: "Facilitator training / on-demand — skip if this is a standard event")
  end

  # --- Before the event ------------------------------------------------------
  def link_organizations
    relevant = @dashboard.has_registrants?
    count = relevant ? @dashboard.unlinked_registration_count : 0
    task(key: :link_organizations, phase: :before, title: "Link organizations", actor: :admin,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.unlinked_registrants : [],
         action_path: registrants_event_path(@event, org_status: "unlinked"), action_label: "Review")
  end

  def allocate_bulk_payments
    relevant = @dashboard.bulk_payment_present?
    count = relevant ? @dashboard.unallocated_bulk_payment_count : 0
    rows = count.positive? ? @dashboard.unallocated_bulk_payment_details.map { |detail| bulk_payment_row(detail) } : []
    task(key: :allocate_bulk_payments, phase: :before, title: "Allocate bulk payments", actor: :admin,
         relevant: relevant, count: count, detail_rows: rows,
         money_cents: relevant ? @dashboard.unallocated_bulk_payment_cents : nil,
         detail: "Received, not yet applied",
         action_path: bulk_payments_event_path(@event), action_label: "Allocate")
  end

  def bulk_payment_row(detail)
    DetailRow.new(
      title: detail.name.presence || "Unknown payer",
      subtitle: detail.organization,
      amount_cents: detail.amount_cents,
      path: bulk_payments_event_path(@event, expand: detail.submission_id, anchor: "payment-card-#{detail.submission_id}")
    )
  end

  def review_flagged_comments
    relevant = @dashboard.has_registrants?
    count = relevant ? @dashboard.flagged_comment_count : 0
    task(key: :review_flagged_comments, phase: :before, title: "Review flagged comments", actor: :admin,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.flagged_comment_registrants : [],
         action_path: registrants_event_path(@event, comment_status: "flagged"), action_label: "Review")
  end

  def collect_registration_fees
    relevant = @dashboard.has_registrants? && !@dashboard.free?
    count = relevant ? @dashboard.unpaid_count : 0
    task(key: :collect_registration_fees, phase: :before, title: "Send reminder: registration fees due", actor: :registrant,
         relevant: relevant, count: count,
         money_cents: relevant ? @dashboard.outstanding_cents : nil,
         registrants: count.positive? ? @dashboard.unpaid_registrants : [],
         action_path: preview_reminder_event_path(@event, payment_status: "unpaid"), action_label: "Send")
  end

  def issue_scholarships
    relevant = @dashboard.scholarship_requests_present? && !@dashboard.free?
    count = relevant ? @dashboard.scholarship_uncreated_count : 0
    task(key: :issue_scholarships, phase: :before, title: "Issue scholarships to requesters", actor: :admin,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.scholarship_uncreated_registrants : [],
         action_path: recipients_event_path(@event), action_label: "Scholarships")
  end

  def set_scholarship_funders
    relevant = @dashboard.scholarships_present? && !@dashboard.free?
    count = relevant ? @dashboard.scholarship_missing_funder_count : 0
    task(key: :set_scholarship_funders, phase: :before, title: "Set scholarship funders", actor: :admin,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.scholarship_missing_funder_registrants : [],
         detail: "No grant assigned — may be an intentional org subsidy",
         action_path: recipients_event_path(@event), action_label: "Scholarships")
  end

  def follow_up_agreements
    relevant = @dashboard.scholarships_present? && !@dashboard.free?
    count = relevant ? @dashboard.scholarship_agreement_unsigned_count : 0
    registrants = count.positive? ? @dashboard.scholarship_agreement_unsigned_registrants : []
    # No semantic reminder filter for "agreement unsigned", so recreate the
    # selection on the reminder page via its name filter (multi-value, split on --).
    action_path = if registrants.any?
      preview_reminder_event_path(@event, name: registrants.map(&:name).join("--"))
    else
      preview_reminder_event_path(@event)
    end
    task(key: :follow_up_agreements, phase: :before, title: "Send reminder: scholarship agreements", actor: :registrant,
         relevant: relevant, count: count, registrants: registrants,
         action_path: action_path, action_label: "Send")
  end

  def fix_zero_scholarships
    relevant = @dashboard.scholarships_present? && !@dashboard.free?
    count = relevant ? @dashboard.scholarship_zero_amount_count : 0
    task(key: :fix_zero_scholarships, phase: :before, title: "Fix $0 scholarship amounts", actor: :admin,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.scholarship_zero_amount_registrants : [],
         action_path: recipients_event_path(@event), action_label: "Scholarships")
  end

  def complete_scholarship_tasks
    relevant = @dashboard.scholarships_present? && !@dashboard.free?
    count = relevant ? @dashboard.scholarship_tasks_incomplete_count : 0
    task(key: :complete_scholarship_tasks, phase: :before, title: "Send reminder: scholarship tasks", actor: :registrant,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.scholarship_tasks_incomplete_registrants : [],
         action_path: preview_reminder_event_path(@event, scholarship: "incomplete"), action_label: "Send")
  end

  def collect_ce_licenses
    relevant = @dashboard.ce_eligible?
    count = relevant ? @dashboard.ce_license_missing_count : 0
    task(key: :collect_ce_licenses, phase: :before, title: "Send reminder: CE license numbers", actor: :registrant,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.ce_license_missing_registrants : [],
         action_path: preview_reminder_event_path(@event, ce_status: "needs_license"), action_label: "Send")
  end

  def collect_ce_fees
    relevant = @dashboard.ce_eligible?
    count = relevant ? @dashboard.cont_ed_unpaid_count : 0
    task(key: :collect_ce_fees, phase: :before, title: "Send reminder: CE fees due", actor: :registrant,
         relevant: relevant, count: count,
         money_cents: relevant ? @dashboard.cont_ed_outstanding_cents : nil,
         registrants: count.positive? ? @dashboard.cont_ed_unpaid_registrants : [],
         action_path: preview_reminder_event_path(@event, ce_status: "requested"), action_label: "Send")
  end

  def issue_ce_certificates
    relevant = @dashboard.ce_eligible?
    count = relevant ? @dashboard.ce_certificate_pending_count : 0
    task(key: :issue_ce_certificates, phase: :before, title: "Issue CE certificates", actor: :admin,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.ce_certificate_pending_registrants : [],
         action_path: registrants_event_path(@event, ce_status: "not_issued"), action_label: "Review")
  end

  def send_pre_event_reminders
    relevant = @dashboard.has_registrants? && !@dashboard.event_over?
    flag(key: :send_pre_event_reminders, phase: :before, title: "Send pre-event reminder emails", actor: :admin,
         relevant: relevant, done: @dashboard.pre_event_reminder_sent?,
         detail: "Goes to all registrants",
         action_path: preview_reminder_event_path(@event), action_label: "Send")
  end

  # --- During & after the event ----------------------------------------------
  def record_attendance
    relevant = @dashboard.has_registrants? && @dashboard.event_started?
    count = relevant ? @dashboard.attendance_pending_count : 0
    task(key: :record_attendance, phase: :after, title: "Record attendance", actor: :admin,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.attendance_pending_registrants : [],
         action_path: registrants_event_path(@event, attendance_status: "registered"), action_label: "Record")
  end

  def reconcile_ce_hours
    relevant = @dashboard.event_over? && @dashboard.ce_eligible?
    count = relevant ? @dashboard.ce_hours_incomplete_count : 0
    task(key: :reconcile_ce_hours, phase: :after, title: "Reconcile CE hours", actor: :admin,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.ce_hours_incomplete_registrants : [],
         detail: "Hours are admin-entered — best-effort",
         action_path: registrants_event_path(@event, ce_status: "registered"), action_label: "Review")
  end

  def send_completion_certificates
    relevant = @dashboard.event_over?
    count = relevant ? @dashboard.completion_certificate_pending_count : 0
    task(key: :send_completion_certificates, phase: :after, title: "Send completion certificates", actor: :admin,
         relevant: relevant, count: count,
         registrants: count.positive? ? @dashboard.completion_certificate_pending_registrants : [],
         action_path: registrants_event_path(@event, readiness: "certificate_due"), action_label: "Review")
  end

  def review_reports
    action(key: :review_reports, phase: :after, title: "Review event reports", actor: :admin,
           relevant: @dashboard.event_over?,
           action_path: statistics_events_path, action_label: "View reports")
  end

  def post_event_survey
    # TODO(post-event-survey): wire up detection + drill-in once the survey
    # feature exists (no survey model/flow is built today).
    placeholder(key: :post_event_survey, phase: :after, title: "Follow up post-event survey",
                detail: "Coming soon (not built)")
  end
end
