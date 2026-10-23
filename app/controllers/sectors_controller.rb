class SectorsController < ApplicationController
  include AhoyTracking, Dedupable
  before_action :set_sector, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(Sector.all)
    filtered = base_scope.filter_scope(params)
    @sectors = filtered.order(:name).paginate(page: params[:page], per_page: per_page)
    @taggings_counts = SectorableItem.where(sector_id: @sectors.map(&:id)).group(:sector_id).count

    @count_display = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"
  end

  def show
    authorize! @sector
  end

  def new
    @sector = Sector.new
    authorize! @sector
    set_form_variables
  end

  def edit
    authorize! @sector
    set_form_variables
  end

  def create
    @sector = Sector.new(sector_params)
    authorize! @sector

    if @sector.save
      redirect_to @sector, notice: "Sector was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @sector
    if @sector.update(sector_params)
      redirect_to after_update_path, notice: "Sector was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @sector
    @sector.destroy!
    redirect_to sectors_path, notice: "Sector was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
  end

  private

  def dedupe_config
    {
      model_class: Sector,
      domain: :sectors
    }
  end

  def after_update_path
    return story_shares_path(sector_names_all: @sector.name) if params[:return_to] == "story_share"

    @sector
  end

  def set_sector
    @sector = Sector.find(params[:id])
  end

  # Strong parameters
  def sector_params
    params.require(:sector).permit(
      :name, :published, :description, :story_share_position, :rhino_story_share_intro
    )
  end
end
