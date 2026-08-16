class ProfessionalLicensesController < ApplicationController
  VALID_SORTS = %w[kind number].freeze

  def index
    authorize!
    scope = ProfessionalLicense.search_by_params(params)
      .includes(:person, :continuing_education_registrations)
    @sort = VALID_SORTS.include?(params[:sort]) ? params[:sort] : nil
    @sort_direction = params[:direction] == "asc" ? "asc" : "desc"
    scope = @sort ? scope.order(@sort.to_sym => @sort_direction) : scope.order(created_at: :desc)
    @professional_licenses = scope.paginate(page: params[:page], per_page: 25)
    render :professional_licenses_results if turbo_frame_request?
  end

  def new
    @professional_license = ProfessionalLicense.new(person_id: params[:person_id])
    authorize! @professional_license
  end

  def create
    @professional_license = ProfessionalLicense.new(professional_license_params)
    @professional_license.created_by = current_user
    authorize! @professional_license

    if @professional_license.save
      redirect_to professional_licenses_path, notice: "License added for #{@professional_license.person.full_name}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def professional_license_params
    params.require(:professional_license).permit(:person_id, :number, :kind, :issuing_state, :expires_on)
  end
end
