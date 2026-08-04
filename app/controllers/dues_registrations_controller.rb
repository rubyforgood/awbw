class DuesRegistrationsController < ApplicationController
  def index
    authorize!
    @dues_registrations = DuesRegistration
      .includes(dues_subscription: :person)
      .order(start_date: :desc)
      .paginate(page: params[:page], per_page: params[:number_of_items_per_page].presence || 25)

    render :dues_registrations_results if turbo_frame_request?
  end
end
