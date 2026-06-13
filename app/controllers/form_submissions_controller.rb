class FormSubmissionsController < ApplicationController
  def show
    @form_submission = FormSubmission.find(params[:id])
    authorize! @form_submission
  end
end
