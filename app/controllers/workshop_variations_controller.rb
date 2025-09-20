class WorkshopVariationsController < ApplicationController

  def index
    @workshop_variations = WorkshopVariation.joins(:workshop).
      where(workshops: { inactive: false }).
      order('workshops.title, workshop_variations.name').
      paginate(page: params[:page], per_page: 25)
  end

  def new
    @workshop_variation = WorkshopVariation.new
    @workshops = Workshop.published
  end

  def create
    @workshop_variation = WorkshopVariation.new(workshop_variation_params)
    if @workshop_variation.save
      flash[:alert] = 'Workshop Variation has been created.'
      redirect_to workshop_variations_path
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
    @workshops = Workshop.published
  end

  def workshop_variation_params
    [:name, :code, :inactive, :ordering, :workshop_id]
  end

end
