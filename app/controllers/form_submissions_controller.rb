class FormSubmissionsController < ApplicationController
  def index
    authorize! FormSubmission

    @person = Person.find_by(id: params[:person_id]) if params[:person_id].present?
    @form = Form.find_by(id: params[:form_id]) if params[:form_id].present?

    if turbo_frame_request?
      @form_submissions = FormSubmission.search_by_params(params)
        .includes(:form, :event, :person)
        .order(created_at: :desc)
        .paginate(page: params[:page], per_page: 50)
      render :form_submissions_results
    else
      @forms = Form.order(:name)
      @roles = FormSubmission.distinct.pluck(:role).compact.sort
      render :index
    end
  end

  def show
    @form_submission = FormSubmission.find(params[:id])
    authorize! @form_submission
  end
end
