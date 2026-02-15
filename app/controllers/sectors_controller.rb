class SectorsController < ApplicationController
  before_action :set_sector, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(Sector.all)
    filtered = base_scope.filter_scope(params)
    @sectors = filtered.order(:name).paginate(page: params[:page], per_page: per_page)

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
      redirect_to sectors_path, notice: "Sector was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @sector
    if @sector.update(sector_params)
      redirect_to sectors_path, notice: "Sector was successfully updated.", status: :see_other
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

  def dedupe_index
    authorize!
    @possible_duplicates = find_possible_duplicates
    @sectors_for_select = Sector.order(:name).map { |s| [ s.name, s.id ] }
  end

  def dedupe_preview
    authorize!
    @sector_to_delete = Sector.find(params[:sector_to_delete_id])
    @sector_to_keep = Sector.find(params[:sector_to_keep_id])
    
    # Get associated records for comparison
    @delete_sectorable_items = @sector_to_delete.sectorable_items.includes(:sectorable)
    @keep_sectorable_items = @sector_to_keep.sectorable_items.includes(:sectorable)
    
    render :dedupe_preview
  end

  def dedupe_execute
    authorize!
    sector_to_delete_id = params[:sector_to_delete_id]
    sector_to_keep_id = params[:sector_to_keep_id]
    
    sector_to_delete = Sector.find(sector_to_delete_id)
    sector_to_keep = Sector.find(sector_to_keep_id)
    
    # Use the deduper service to perform the merge
    deduper = SectorDeduper.new(logger: Rails.logger, dry_run: false, min_usage: 0)
    deduper.merge_sectors(sector_to_keep, sector_to_delete)
    
    redirect_to sectors_path, notice: "Sectors merged successfully. '#{sector_to_delete.name}' was merged into '#{sector_to_keep.name}'."
  rescue StandardError => e
    redirect_to dedupe_index_sectors_path, alert: "Error merging sectors: #{e.message}"
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
  end

  private

  def find_possible_duplicates
    # Group sectors by normalized name to find duplicates
    groups = Sector.all.group_by { |s| s.name.to_s.strip.downcase }
    groups.select { |_name, sectors| sectors.size > 1 }
  end

  def set_sector
    @sector = Sector.find(params[:id])
  end

  # Strong parameters
  def sector_params
    params.require(:sector).permit(
      :name, :published
    )
  end
end
