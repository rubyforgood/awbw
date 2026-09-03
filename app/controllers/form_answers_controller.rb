class FormAnswersController < ApplicationController
  # Blank answer rows are noise here (an optional question nobody filled in), so
  # they're hidden unless the Empty answers filter asks for them. Hiding them by
  # default also makes this list agree with the response counts on form results,
  # which have always counted only answered questions.
  INCLUDE_EMPTY_ANSWERS = "include".freeze

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
      # Names the "back to results" eyebrow when a form's results page linked here.
      @form = Form.find_by(id: params[:form_id])
      render :index
    end
  end

  private

  # Each filter is a no-op when its param is blank, so combinations stack.
  def filter_answers(scope)
    scope = scope.answered unless params[:empty] == INCLUDE_EMPTY_ANSWERS
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
    if params[:event_id].present?
      scope = scope.joins(:form_submission).where(form_submissions: { event_id: params[:event_id] })
    end
    if params[:organization_id].present?
      scope = scope.where(form_submission_id: FormSubmission.for_organization(params[:organization_id]).select(:id))
    end
    if params[:person_id].present?
      scope = scope.joins(:form_submission).where(form_submissions: { person_id: params[:person_id] })
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
