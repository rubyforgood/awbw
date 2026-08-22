class FormAnswersController < ApplicationController
  def index
    authorize! FormAnswer

    if turbo_frame_request?
      @form_answers = filter_answers(FormAnswer.all)
                        .includes(:form_field, form_submission: [ :form, :person ])
                        .order(created_at: :desc)
                        .paginate(page: params[:page], per_page: 50)
      render :form_answers_results
    else
      @forms = Form.order(:name)
      render :index
    end
  end

  private

  # Each filter is a no-op when its param is blank, so combinations stack.
  def filter_answers(scope)
    if params[:q].present?
      scope = scope.where("form_answers.submitted_answer LIKE ?", "%#{FormAnswer.sanitize_sql_like(params[:q])}%")
    end
    if params[:question].present?
      term = "%#{FormField.sanitize_sql_like(params[:question])}%"
      scope = scope.left_joins(:form_field).where(
        "form_fields.name LIKE :t OR form_answers.question_name_when_answered LIKE :t", t: term
      )
    end
    if params[:form_id].present?
      scope = scope.joins(:form_submission).where(form_submissions: { form_id: params[:form_id] })
    end
    if params[:person].present?
      term = "%#{Person.sanitize_sql_like(params[:person])}%"
      scope = scope.joins(form_submission: :person).where(
        "people.first_name LIKE :t OR people.last_name LIKE :t OR people.email LIKE :t OR CONCAT(people.first_name, ' ', people.last_name) LIKE :t",
        t: term
      )
    end
    if params[:form_submission_id].present?
      scope = scope.where(form_submission_id: params[:form_submission_id])
    end
    if params[:answer_type].present? && FormField.answer_types.key?(params[:answer_type])
      scope = scope.joins(:form_field).where(form_fields: { answer_type: FormField.answer_types[params[:answer_type]] })
    end
    scope
  end
end
