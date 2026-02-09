class OrganizationStatusesController < ApplicationController
  before_action :set_organization_status, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(OrganizationStatus.all)
    @count_display = base_scope.count
    @organization_statuses = base_scope.paginate(page: params[:page], per_page: per_page).decorate
  end

  def show
    @organization_status = @organization_status.decorate
    authorize! @organization_status
  end

  def new
    @organization_status = OrganizationStatus.new.decorate
    authorize! @organization_status
    set_form_variables
  end

  def edit
    @organization_status = @organization_status.decorate
    authorize! @organization_status
    set_form_variables
  end

  def create
    @organization_status = OrganizationStatus.new(organization_status_params)
    authorize! @organization_status

    if @organization_status.save
      redirect_to organization_statuses_path, notice: "Organization status was successfully created."
    else
      @organization_status = OrganizationStatus.new.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @organization_status
    if @organization_status.update(organization_status_params)
      redirect_to organization_statuses_path, notice: "Organization status was successfully updated.", status: :see_other
    else
      @organization_status = OrganizationStatus.new.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @organization_status
    @organization_status.destroy!
    redirect_to organization_statuses_path, notice: "Organization status was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
  end

  private

  def set_organization_status
    @organization_status = OrganizationStatus.find(params[:id])
  end

  # Strong parameters
  def organization_status_params
    params.require(:organization_status).permit(
      :name
    )
  end
end
