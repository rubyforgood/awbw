module EventsHelper
  # Ordered column descriptors for the event Onboarding matrix. The array index
  # is the table-sort column index, so the header row and every body row iterate
  # this same list — keeping header buttons and cell positions aligned no matter
  # which optional columns (payment, attendance days) are present.
  def onboarding_columns(event)
    columns = [
      { key: "name", label: "Name", kind: :name, sortable: true, align: "left", sticky: true },
      { key: "progress", label: "Progress", kind: :progress, sortable: true, align: "center" },
      { key: "program", label: "Organization", kind: :program, sortable: true, align: "left", toggle: "program" },
      { key: "program_type", label: "Program type", kind: :program_type, sortable: true, align: "center", toggle: "program_type" }
    ]
    columns << { key: "payment", label: "Payment", kind: :payment, sortable: true, align: "center", toggle: "payment" } if event.cost_cents.to_i > 0
    columns << { key: "scholarship", label: "Scholarship", kind: :scholarship, sortable: true, align: "center", toggle: "scholarship" }
    columns << { key: "fee_note", label: "Fee note", kind: :fee_note, sortable: false, align: "center", toggle: "fee_note" }
    EventRegistration::CHECKLIST_STEPS.each do |step, label|
      columns << { key: step, label: label, kind: :checkbox, field: step, sortable: true, align: "center", toggle: step }
    end
    columns << { key: "attendance", label: "Attendance", kind: :attendance, sortable: true, align: "center", toggle: "attendance" }
    (1..event.day_count).each do |day|
      columns << { key: "completed_day_#{day}", label: "Day #{day}", kind: :checkbox, field: "completed_day_#{day}", sortable: true, align: "center", toggle: "days" }
    end
    columns << { key: "edit", label: "", kind: :edit, sortable: false, align: "right" }
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
