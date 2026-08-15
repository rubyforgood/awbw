class ProfessionalLicensesController < ApplicationController
  def index
    authorize!
    @professional_licenses = ProfessionalLicense.search_by_params(params)
      .includes(:person, :continuing_education_registrations)
      .order(created_at: :desc)
      .paginate(page: params[:page], per_page: 25)
    render :professional_licenses_results if turbo_frame_request?
  end
end
