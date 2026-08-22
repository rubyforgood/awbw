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

  # Turn a form answer into a draft Quote so an admin can finalize it. The quote
  # carries no author — an unattributed quote reads as "Participant" — and records
  # the submitter as its creator (per the request that a quote track who it came
  # from). Lands in the quote editor to set the speaker, tags, and publish.
  #
  # Re-promoting the same answer is idempotent: a quote whose untouched
  # `original_body` still matches this answer (from the same submitter) is reused
  # rather than duplicated, so a second click reopens the existing quote. The
  # guard keys on `original_body` — not the editable `body` — so it survives the
  # admin refining the published text, and only applies when there is a creator to
  # scope by, so it can't false-match an unrelated authorless quote.
  def promote_to_quote
    answer = FormAnswer.find(params[:id])
    creator = answer.form_submission.person&.user
    quote = Quote.new(body: answer.submitted_answer, created_by: creator)
    authorize! quote, to: :create?

    if answer.submitted_answer.blank?
      redirect_back fallback_location: form_answers_path, alert: "That answer is empty — nothing to promote."
      return
    end

    existing = creator && Quote.find_by(original_body: answer.submitted_answer, created_by: creator)
    if existing
      redirect_to edit_quote_path(existing), notice: "This answer is already a quote — here it is."
    elsif quote.save
      redirect_to edit_quote_path(quote), notice: "Quote created from the answer. Finish setting it up here."
    else
      redirect_back fallback_location: form_answers_path, alert: "Couldn't create the quote: #{quote.errors.full_messages.to_sentence}"
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
    if params[:event_id].present?
      scope = scope.joins(:form_submission).where(form_submissions: { event_id: params[:event_id] })
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
