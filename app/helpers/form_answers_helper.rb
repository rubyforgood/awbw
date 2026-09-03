module FormAnswersHelper
  # The index filters a submission's detail page must hand back so the trip to
  # View a submission and back lands on the same filtered list. Blank values are
  # dropped. Mirrors FormSubmissionsHelper#form_submission_carryover_params.
  def form_answer_carryover_params(params)
    {
      q: params[:q].presence,
      question: params[:question].presence,
      form_field_id: params[:form_field_id].presence,
      results_question: params[:results_question].presence,
      answer_type: params[:answer_type].presence,
      form_id: params[:form_id].presence,
      event_id: params[:event_id].presence,
      person_id: params[:person_id].presence,
      organization_id: params[:organization_id].presence,
      form_submission_id: params[:form_submission_id].presence,
      start_date: params[:start_date].presence,
      end_date: params[:end_date].presence,
      empty: params[:empty].presence
    }.compact
  end
end
