class BulkPaymentsController < ApplicationController
  def index
    authorize! FormSubmission, to: :index?

    if turbo_frame_request?
      @submissions = FormSubmission.bulk_payment
        .search_by_params(params)
        .includes(:person, :event, :payment, { form: :events })
        .order(created_at: :desc)
        .paginate(page: params[:page], per_page: 50)
      render :bulk_payments_results
    else
      render :index
    end
  end
end
