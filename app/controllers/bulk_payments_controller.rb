class BulkPaymentsController < ApplicationController
  include AhoyTracking

  def index
    authorize! FormSubmission, to: :index?

    if turbo_frame_request?
      @submissions = FormSubmission.bulk_payment
        .search_by_params(params)
        .includes(:person, :event, :payment, { form: :events }, { form_answers: :form_field })
        .order(created_at: :desc)
        .paginate(page: params[:page], per_page: 50)
      render :bulk_payments_results
    else
      track_view("bulk_payments")
      render :index
    end
  end
end
