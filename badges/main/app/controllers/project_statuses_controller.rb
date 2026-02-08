class ProjectStatusesController < ApplicationController
  before_action :set_project_status, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    unfiltered = ProjectStatus.all
    @count_display = unfiltered.count
    @project_statuses = unfiltered.paginate(page: params[:page], per_page: per_page).decorate
  end

  def show
    @project_status = @project_status.decorate
    authorize! @project_status
  end

  def new
    @project_status = ProjectStatus.new.decorate
    authorize! @project_status
    set_form_variables
  end

  def edit
    @project_status = @project_status.decorate
    authorize! @project_status
    set_form_variables
  end

  def create
    @project_status = ProjectStatus.new(project_status_params)
    authorize! @project_status

    if @project_status.save
      redirect_to project_statuses_path, notice: "Project status was successfully created."
    else
      @project_status = ProjectStatus.new.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @project_status
    if @project_status.update(project_status_params)
      redirect_to project_statuses_path, notice: "Project status was successfully updated.", status: :see_other
    else
      @project_status = ProjectStatus.new.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @project_status
    @project_status.destroy!
    redirect_to project_statuses_path, notice: "Project status was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
  end

  private

  def set_project_status
    @project_status = ProjectStatus.find(params[:id])
  end

  # Strong parameters
  def project_status_params
    params.require(:project_status).permit(
      :name
    )
  end
end
