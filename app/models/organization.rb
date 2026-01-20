class Organization < Project
  # Organization is an alias for Project
  # This provides a semantic interface for organization-specific functionality
  self.table_name = "projects"

  # Get all annual evaluation responses for a specific year
  def annual_evaluations_for_year(year)
    return Report.none unless year.present?

    start_date = Date.new(year.to_i, 1, 1)
    end_date = Date.new(year.to_i, 12, 31).end_of_day

    Report.joins(form: :form_builder)
          .joins(:user)
          .joins("INNER JOIN project_users ON project_users.user_id = reports.user_id")
          .where(project_users: { project_id: id })
          .where(form_builders: { name: "Annual Evaluation" })
          .where(created_at: start_date..end_date)
          .distinct
  end

  # Get aggregated responses by form field for a year
  def aggregated_annual_evaluation_responses(year)
    evaluations = annual_evaluations_for_year(year)
    return {} if evaluations.empty?

    form_builder = FormBuilder.find_by(name: "Annual Evaluation")
    return {} unless form_builder

    form = form_builder.forms.first
    return {} unless form

    # Group responses by form field
    form.form_fields.active.order(position: :desc).map do |field|
      responses = ReportFormFieldAnswer
                    .where(report_id: evaluations.pluck(:id), form_field_id: field.id)
                    .includes(:answer_option, report: :user)

      {
        form_field: field,
        responses: responses
      }
    end
  end
end
