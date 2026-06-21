module EventsHelper
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
    columns += [
      { key: "email", label: "Email", kind: :email, sortable: true, align: "left" },
      { key: "program", label: "Organization", kind: :program, sortable: true, align: "left", toggle: "program" },
      { key: "program_type", label: "Program type", kind: :program_type, sortable: true, align: "center", toggle: "program_type" }
    ]
    if event.cost_cents.to_i > 0
      columns << { key: "payment", label: "Payment", kind: :payment, sortable: true, align: "center", toggle: "payment" }
      columns << { key: "fees_due", label: "Fees due", kind: :fees_due, sortable: true, align: "center", toggle: "fees_due" }
      columns << { key: "paid", label: "Paid", kind: :paid, sortable: true, align: "center", toggle: "paid" }
    end
    columns << { key: "scholarship_amount", label: "Scholarship amount", kind: :scholarship_amount, sortable: true, align: "center", toggle: "scholarship_amount" }
    columns << { key: "funder", label: "Scholarship grant", kind: :funder, sortable: true, align: "left", toggle: "funder" }
    columns << { key: "scholarship_tasks_completed", label: "Scholarship tasks done", kind: :scholarship_tasks, sortable: true, align: "center", toggle: "scholarship_tasks_completed" }
    columns << { key: "ce_requested", label: "CE requested", kind: :ce_requested, sortable: true, align: "center", toggle: "ce_requested" }
    columns << { key: "ce_hours", label: "CE hours", kind: :ce_hours, sortable: true, align: "center", toggle: "ce_hours" }
    columns << { key: "ce_amount", label: "CE amount", kind: :ce_amount, sortable: true, align: "center", toggle: "ce_amount" }
    columns << { key: "ce_license", label: "License #", kind: :ce_license, sortable: true, align: "center", toggle: "ce_license" }
    columns << { key: "fee_note", label: "Fee note", kind: :fee_note, sortable: false, align: "center", toggle: "fee_note" }
    columns << { key: "portal_invite", label: "Portal invite", kind: :portal_invite, sortable: true, align: "center", toggle: "portal_invite" }
    EventRegistration::CHECKLIST_STEPS.each do |step, label|
      columns << { key: step, label: label, kind: :checkbox, field: step, sortable: true, align: "center", toggle: step }
    end
    columns << { key: "flagged_comments", label: "Flagged comments", kind: :flagged_comments, sortable: true, align: "center", toggle: "flagged_comments" }
    columns << { key: "comments", label: "Comments", kind: :comments, sortable: true, align: "left", toggle: "comments" }
    columns << { key: "attendance", label: "Event attendance", kind: :attendance, sortable: true, align: "center", toggle: "attendance" }
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
end
