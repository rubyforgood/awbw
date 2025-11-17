class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unpaginated = Project.search_by_params(params).order(:name)
    @projects_count = unpaginated.count
    @projects = unpaginated.paginate(page: params[:page], per_page: per_page)
    set_index_variables
  end

  def show
    # Reuse WorkshopLogsController#index logic programmatically
    workshop_logs_controller = WorkshopLogsController.new
    workshop_logs_controller.request = request
    workshop_logs_controller.response = response
    params[:project_id] = @project.id  # Inject context so the WorkshopLogsController#index scopes properly
    workshop_logs_controller.params = params
    workshop_logs_controller.index

    workshop_logs = WorkshopLog.where(project_id: @project.id)
    @month_year_options = workshop_logs.group("DATE_FORMAT(COALESCE(date, created_at, NOW()), '%Y-%m')")
                                     .select("DATE_FORMAT(COALESCE(date, created_at, NOW()), '%Y-%m') AS ym,
           MAX(COALESCE(date, created_at)) AS max_dt")
                                     .order("max_dt DESC")
                                     .map { |record| [Date.strptime(record.ym, "%Y-%m").strftime("%B %Y"), record.ym] }

    @year_options = workshop_logs.pluck(
      Arel.sql("DISTINCT EXTRACT(YEAR FROM COALESCE(date, created_at, NOW()))")
    ).sort.reverse
    @projects = Project.where(id: @project.id)
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
    @project = Project.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to projects_path, notice: "Project was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @project.update(project_params)
      redirect_to projects_path, notice: "Project was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @project.destroy!
    redirect_to projects_path, notice: "Project was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @project_statuses = ProjectStatus.all
  end

  def set_index_variables
    @project_statuses = ProjectStatus.all
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  # Strong parameters
  def project_params
    params.require(:project).permit(
      :name, :description, :start_date, :end_date, :mission_vision_values, :internal_id,
      :inactive, :notes, :agency_type,  :agency_type_other, :website_url,
      :project_status_id, :location_id, :windows_type_id,

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
        :_destroy,
      ]
    )
  end
end
