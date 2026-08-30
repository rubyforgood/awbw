class FormDecorator < ApplicationDecorator
  # A legacy owner-attached form's answers don't live in the form-submission
  # system: a FormBuilder-owned report/log template stores its answers as
  # report_form_field_answers, surfaced on the reporting indexes. Resolve the
  # best "view answers" path for the form's owner, falling back to the standard
  # form Results rollup for anything else.
  def answers_path
    return h.results_form_path(object) unless owner.is_a?(FormBuilder)

    case owner.report_type
    when "WorkshopLog" then h.workshop_logs_path
    when "MonthlyReport" then h.monthly_reports_path(form_builder_id: owner.id)
    else h.results_form_path(object)
    end
  end

  # Where the answers link points, in words, so the legacy row reads clearly.
  def answers_label
    return "View answers" unless owner.is_a?(FormBuilder)

    case owner.report_type
    when "WorkshopLog" then "View workshop logs"
    when "MonthlyReport" then "View monthly reports"
    else "View answers"
    end
  end

  # What this form is attached to, e.g. "Report template · Adult Workshop Log"
  # or "Event · Spring Retreat".
  def owner_label
    return "" unless owner

    kind = owner.is_a?(FormBuilder) ? "Report template" : owner_type.underscore.humanize
    "#{kind} · #{owner.try(:name)}"
  end
end
