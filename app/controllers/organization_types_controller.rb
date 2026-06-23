class OrganizationTypesController < ApplicationController
  include AhoyTracking
  before_action :set_organization_type, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(OrganizationType.all)
    filtered = base_scope.filter_scope(params)
    @organization_types = filtered.ordered.paginate(page: params[:page], per_page: per_page)
    @organization_counts = Organization.where(organization_type_id: @organization_types.map(&:id))
                                        .group(:organization_type_id).count

    @count_display = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"
  end

  def show
    authorize! @organization_type
  end

  def new
    @organization_type = OrganizationType.new
    authorize! @organization_type
  end

  def edit
    authorize! @organization_type
  end

  def create
    @organization_type = OrganizationType.new(organization_type_params)
    authorize! @organization_type

    if @organization_type.save
      redirect_to @organization_type, notice: "Organization type was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @organization_type
    if @organization_type.update(organization_type_params)
      redirect_to @organization_type, notice: "Organization type was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @organization_type
    @organization_type.destroy!
    redirect_to organization_types_path, notice: "Organization type was successfully destroyed."
  end

  private

  def set_organization_type
    @organization_type = OrganizationType.find(params[:id])
  end

  def organization_type_params
    params.require(:organization_type).permit(:name, :published, :description)
  end
end
