class OrganizationsController < ApplicationController
  before_action :authenticate_user!, except: [ :index, :show ]
  before_action :set_organization, only: [ :show, :edit, :update, :destroy, :annual_evaluations ]

  def index
    @organizations = Organization.all
  end

  def show
  end

  def new
    @organization = Organization.new
  end

  def edit
  end

  def create
    @organization = Organization.new(organization_params)

    if @organization.save
      redirect_to @organization, notice: "Organization was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @organization.update(organization_params)
      redirect_to @organization, notice: "Organization was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @organization.destroy!
    redirect_to organizations_url, notice: "Organization was successfully destroyed."
  end

  def annual_evaluations
    @year = params[:year]&.to_i || Date.current.year
    @aggregated_responses = @organization.aggregated_annual_evaluation_responses(@year)

    # Get available years that have evaluations
    all_evaluations = Report.joins(form: :form_builder)
                            .joins(:user)
                            .joins("INNER JOIN project_users ON project_users.user_id = reports.user_id")
                            .where(project_users: { project_id: @organization.id })
                            .where(form_builders: { name: "Annual Evaluation" })
                            .distinct

    @available_years = all_evaluations.pluck(:created_at).map(&:year).uniq.sort.reverse
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(
      :name, :description, :website_url, :start_date, :end_date,
      :agency_type, :agency_type_other, :mission_vision_values,
      :internal_id, :filemaker_code, :inactive, :notes,
      :project_status_id, :windows_type_id, :location_id,
      addresses_attributes: [ :id, :street_address, :city, :state, :zip_code, :country, :_destroy ],
      sectorable_items_attributes: [ :id, :sector_id, :_destroy ]
    )
  end
end
