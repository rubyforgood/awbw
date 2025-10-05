class WorkshopVariationsController < ApplicationController

  def index
    if current_user.super_user?
      @workshop_variations = WorkshopVariation.joins(:workshop).
        where(workshops: { inactive: false }).
        order('workshops.title, workshop_variations.name').
        paginate(page: params[:page], per_page: 25)
    else
      redirect_to authenticated_root_path
    end
  end

  def new
    @workshop_variation = WorkshopVariation.new
    @workshops = Workshop.published.order(:title)
  end

  def create
    @workshop_variation = WorkshopVariation.new(workshop_variation_params)
    if @workshop_variation.save
      flash[:notice] = 'Workshop Variation has been created.'
      if params[:from] == "workshop_show"
        redirect_to workshop_path(@workshop_variation.workshop)
      elsif params[:from] == "index"
        redirect_to workshop_variations_path
      else
        redirect_to authenticated_root_path
      end
    else
      render :new
    end
  end

  def show
    @workshop_variation = WorkshopVariation.find(params[:id]).decorate
    @workshop = @workshop_variation.workshop.decorate
    @bookmark = current_user.bookmarks.find_by(bookmarkable: @workshop)
    @new_bookmark = @workshop.bookmarks.build
    @quotes = @workshop.quotes
    @workshop_variations = @workshop.workshop_variations
    @sectors = @workshop.sectors
  end

  def edit
    @workshop_variation = WorkshopVariation.find(params[:id])
    @workshops = Workshop.published.order(:title)
  end

  def update
    @workshop_variation = WorkshopVariation.find(params[:id])

    if @workshop_variation.update(workshop_variation_params)
      flash[:notice] = 'Workshop Variation updated successfully.'
      redirect_to workshop_variations_path
    else
      flash[:alert] = 'Unable to update Workshop Variation.'
      render :edit
    end
  end

  def workshop_variation_params
    params.require(:workshop_variation).permit(
      [:name, :code, :inactive, :ordering, :workshop_id])
  end

end
