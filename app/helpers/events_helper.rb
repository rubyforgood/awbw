module EventsHelper
  # Ordered column descriptors for the event Onboarding matrix. The array index
  # is the table-sort column index, so the header row and every body row iterate
  # this same list — keeping header buttons and cell positions aligned no matter
  # which optional columns (payment, attendance days) are present.
  def onboarding_columns(event)
    columns = [
      { key: "edit", label: "", kind: :edit, sortable: false, align: "center", sticky: true },
      { key: "first_name", label: "First", kind: :first_name, sortable: true, align: "left" },
      { key: "last_name", label: "Last", kind: :last_name, sortable: true, align: "left" },
      { key: "email", label: "Email", kind: :email, sortable: true, align: "left" },
      { key: "progress", label: "Progress", kind: :progress, sortable: true, align: "center" },
      { key: "program", label: "Organization", kind: :program, sortable: true, align: "left", toggle: "program" },
      { key: "program_type", label: "Program type", kind: :program_type, sortable: true, align: "center", toggle: "program_type" }
    ]
    if event.cost_cents.to_i > 0
      columns << { key: "payment", label: "Payment", kind: :payment, sortable: true, align: "center", toggle: "payment" }
      columns << { key: "fees_due", label: "Fees due", kind: :fees_due, sortable: true, align: "center", toggle: "fees_due" }
    end
    columns << { key: "scholarship", label: "Scholarship", kind: :scholarship, sortable: true, align: "center", toggle: "scholarship" }
    columns << { key: "scholarship_tasks_completed", label: "Tasks done", kind: :scholarship_tasks, sortable: true, align: "center", toggle: "scholarship_tasks_completed" }
    columns << { key: "fee_note", label: "Fee note", kind: :fee_note, sortable: false, align: "center", toggle: "fee_note" }
    columns << { key: "portal_invite", label: "Portal invite", kind: :portal_invite, sortable: true, align: "center", toggle: "portal_invite" }
    EventRegistration::CHECKLIST_STEPS.each do |step, label|
      columns << { key: step, label: label, kind: :checkbox, field: step, sortable: true, align: "center", toggle: step }
    end
    columns << { key: "attendance", label: "Attendance", kind: :attendance, sortable: true, align: "center", toggle: "attendance" }
    (1..event.day_count).each do |day|
      columns << { key: "completed_day_#{day}", label: "Day #{day}", kind: :checkbox, field: "completed_day_#{day}", sortable: true, align: "center", toggle: "days" }
    end
    columns << { key: "comments", label: "Comments", kind: :comments, sortable: true, align: "center", toggle: "comments" }
    columns
  end

  # Distinct column-visibility menu entries (label keyed by data-onboarding-col),
  # collapsing the per-day columns into a single "Attendance days" toggle.
  def onboarding_toggle_entries(event)
    onboarding_columns(event).each_with_object({}) do |column, entries|
      attr = column[:toggle]
      next if attr.blank? || entries.key?(attr)

      entries[attr] = attr == "days" ? "Attendance days" : column[:label]
    end
  end
end
