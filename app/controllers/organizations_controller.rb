class OrganizationsController < ApplicationController
  before_action :set_organization, only: [ :show, :edit, :update, :destroy ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unpaginated = Organization.search_by_params(params).order(:name)
    @organizations_count = unpaginated.count
    @organizations = unpaginated.paginate(page: params[:page], per_page: per_page)
    set_index_variables
  end

  def show
    @organization.increment_view_count!(session: session, request: request)

    # Reuse WorkshopLogsController#index logic programmatically
    workshop_logs_controller = WorkshopLogsController.new
    workshop_logs_controller.request = request
    workshop_logs_controller.response = response
    params[:organization_id] = @organization.id  # Inject context so the WorkshopLogsController#index scopes properly
    workshop_logs_controller.params = params
    workshop_logs_controller.index

    workshop_logs = WorkshopLog.where(organization_id: @organization.id)
    @month_year_options = workshop_logs.group("DATE_FORMAT(COALESCE(date, created_at, NOW()), '%Y-%m')")
                                     .select("DATE_FORMAT(COALESCE(date, created_at, NOW()), '%Y-%m') AS ym,
           MAX(COALESCE(date, created_at)) AS max_dt")
                                     .order("max_dt DESC")
                                     .map { |record| [ Date.strptime(record.ym, "%Y-%m").strftime("%B %Y"), record.ym ] }

    @year_options = workshop_logs.pluck(
      Arel.sql("DISTINCT EXTRACT(YEAR FROM COALESCE(date, created_at, NOW()))")
    ).sort.reverse
    @organizations = Organization.where(id: @organization.id)
    @per_page = params[:per_page] || 10
    @workshop_logs_unpaginated = workshop_logs
    @workshop_logs_count = @workshop_logs_unpaginated.size
    @workshop_logs = @workshop_logs_unpaginated.paginate(page: params[:page], per_page: @per_page)
    @facilitators = User.active.or(User.where(id: @workshop_logs_unpaginated.pluck(:user_id)))
                        .joins(:workshop_logs)
                        .distinct
                        .order(:last_name, :first_name)
  end

  def new
    @organization = Organization.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @organization = Organization.new(organization_params)

    if @organization.save
      redirect_to organizations_path, notice: "Organization was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @organization.update(organization_params)
      redirect_to organizations_path, notice: "Organization was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @organization.destroy!
    redirect_to organizations_path, notice: "Organization was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @organization_statuses = OrganizationStatus.all
    @facilitators_array = Facilitator.joins(:user)
                                     .order(:first_name, :last_name)
                                     .map { |f| [ f.name, f.user.id ] }
    @organization.organization_users = @organization.organization_users
                                     .includes(:organization)
                                     .sort_by { |ou| ou.user.facilitator&.name.to_s.downcase }
  end

  def set_index_variables
    @organization_statuses = OrganizationStatus.all
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  # Strong parameters
  def organization_params
    params.require(:organization).permit(
      :name, :description, :start_date, :end_date, :mission_vision_values, :internal_id,
      :inactive, :logo, :notes, :agency_type,  :agency_type_other, :website_url,
      :organization_status_id, :location_id, :windows_type_id,
      sectorable_items_attributes: [
        :id,
        :sector_id,
        :_destroy
      ],
      organization_users_attributes: [
        :id,
        :user_id,
        :inactive,
        :title,
        :_destroy
      ],
      addresses_attributes: [
        :id,
        :address_type,
        :inactive,
        :phone,
        :street_address,
        :city,
        :state,
        :zip_code,
        :county,
        :country,
        :district,
        :locality,
        :la_city_council_district,
        :la_supervisorial_district,
        :la_service_planning_area,
        :_destroy
      ]
    )
  end
end
