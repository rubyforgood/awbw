class FormSubmissionsController < ApplicationController
  def index
    authorize! FormSubmission
    submissions = FormSubmission.includes(:form, :event, :person)
    if params[:person_id].present?
      submissions = submissions.where(person_id: params[:person_id])
      @person = Person.find_by(id: params[:person_id])
    end
    @form_submissions = submissions.order(created_at: :desc)
  end

  def show
    @form_submission = FormSubmission.find(params[:id])
    authorize! @form_submission
  end
end
