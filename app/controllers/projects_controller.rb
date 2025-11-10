class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unpaginated = Project.all
    @projects_count = unpaginated.count
    @projects = unpaginated.paginate(page: params[:page], per_page: per_page)
    set_index_variables
  end

  def show
    # Reuse WorkshopLogsController#index logic programmatically
    workshop_logs_controller = WorkshopLogsController.new
    workshop_logs_controller.request = request
    workshop_logs_controller.response = response

    # Inject context so the WorkshopLogsController#index scopes properly
    params[:project_id] = @project.id
    workshop_logs_controller.params = params

    workshop_logs_controller.index
    @month_year_options = WorkshopLog.where.not(date: nil)
                                     .group("DATE_FORMAT(COALESCE(date, created_at), '%Y-%m')")
                                     .select("DATE_FORMAT(COALESCE(date, created_at), '%Y-%m') AS ym, MAX(COALESCE(date, created_at)) AS max_dt")
                                     .order("max_dt DESC")
                                     .map { |record| [Date.strptime(record.ym, "%Y-%m").strftime("%B %Y"), record.ym] }
    @year_options = WorkshopLog.pluck(Arel.sql("DISTINCT EXTRACT(YEAR FROM COALESCE(date, created_at))"))
                               .sort
                               .reverse
    @facilitators = User.joins(:workshop_logs)
                        .distinct
                        .order(:last_name, :first_name)
    @projects = Project.where(id: @project.id)
    @per_page = params[:per_page] || 10
    @workshop_logs_unpaginated = @project.workshop_logs
    @workshop_logs_count = @workshop_logs_unpaginated.size
    @workshop_logs = @workshop_logs_unpaginated.paginate(page: params[:page], per_page: @per_page)
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
      :windows_type_id, :name, :description, :start_date, :end_date, :project_status_id,
      :location_id, :district, :locality, :inactive, :notes
    )
  end
end
