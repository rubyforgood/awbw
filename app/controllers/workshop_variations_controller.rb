class WorkshopVariationsController < ApplicationController
  include AhoyTracking
  def index
    authorize!

    base_scope = WorkshopVariation.includes(:workshop).joins(:workshop).where(workshops: { published: true })
    filtered = base_scope.search_by_params(params)
                         .order("workshop_variations.created_at DESC, workshops.title, workshop_variations.name")
    @workshop_variations = filtered.paginate(page: params[:page], per_page: 25).decorate
    @workshop_variations_count = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"
  end

  def new
    if params[:workshop_variation_idea_id].present?
      idea = WorkshopVariationIdea.find(params[:workshop_variation_idea_id])
      @workshop_variation = WorkshopVariationFromIdeaService.new(idea, user: current_user).call
    else
      @workshop_variation = WorkshopVariation.new
    end
    authorize! @workshop_variation
    set_form_variables
  end

  def create
    @workshop_variation = current_user.workshop_variations_as_creator.build(workshop_variation_params)
    authorize! @workshop_variation

    success = false

    WorkshopVariation.transaction do
      if @workshop_variation.save
        # assign_associations(@workshop_variation)
        if params[:promote_idea_assets] == "true"
          @workshop_variation.attach_assets_from_idea!
        end

        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      log_workshop_error("creation", e)
      raise ActiveRecord::Rollback
    end

    if success
      flash[:notice] = "Workshop Variation has been created."
      redirect_to workshop_variations_path(sort: "created")
    else
      set_form_variables
      flash.now[:alert] = "Unable to save the workshop variation."
      render :new
    end
  end

  def show
    @workshop_variation = WorkshopVariation.find(params[:id]).decorate
    authorize! @workshop_variation
    track_view(@workshop_variation)

    @workshop = @workshop_variation.workshop.decorate
    @bookmark = current_user.bookmarks.find_by(bookmarkable: @workshop)
    @new_bookmark = @workshop.bookmarks.build
    @quotes = @workshop.quotes
    @workshop_variations = @workshop.workshop_variations
    @sectors = @workshop.sectors
  end

  def edit
    @workshop_variation = WorkshopVariation.find(params[:id])
    authorize! @workshop_variation
    @workshops = Workshop.published.order(:title)
    set_form_variables
  end

  def update
    @workshop_variation = WorkshopVariation.find(params[:id])
    authorize! @workshop_variation

    if @workshop_variation.update(workshop_variation_params)
      flash[:notice] = "Workshop Variation updated successfully."
      redirect_to workshop_variations_path
    else
      set_form_variables
      flash[:alert] = "Unable to update Workshop Variation."
      render :edit
    end
  end

  private
  # def assign_associations(workshop_variation)
  #   # Convert checkbox values into categorizable_items updates
  #   selected_category_ids = Array(params[:workshop_variation][:category_ids]).reject(&:blank?).map(&:to_i)
  #   workshop_variation.categories = Category.where(id: selected_category_ids)
  #
  #   # Convert checkbox values into sectorable_items updates
  #   selected_sector_ids = Array(params[:workshop_variation][:sector_ids]).reject(&:blank?).map(&:to_i)
  #   workshop_variation.sectors = Sector.where(id: selected_sector_ids)
  # workshop.save!
  # end

  def set_form_variables
    workshops = authorized_scope(Workshop.all)
    @workshops = workshops.order(:title)
    @workshop = @workshop_variation.workshop || params[:workshop_id].present? &&
      Workshop.where(id: params[:workshop_id]).last
    @workshop_variation_idea = params[:workshop_variation_idea_id].present? &&
      WorkshopVariationIdea.find_by(id: params[:workshop_variation_idea_id])
  end

  def workshop_variation_params
    params.require(:workshop_variation).permit(
      [ :name, :rhino_body, :published, :position, :youtube_url, :created_by_id,
        :organization_id, :workshop_id, :workshop_variation_idea_id
      ]
    )
  end
end
