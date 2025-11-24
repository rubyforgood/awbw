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
    workshops = current_user.super_user? ? Workshop.all : Workshop.published
    @workshops = workshops.order(:title)
    @workshop = @workshop_variation.workshop || params[:workshop_id].present? &&
      Workshop.where(id: params[:workshop_id]).last
    set_form_variables
  end

  def create
    @workshop_variation = WorkshopVariation.new(workshop_variation_params)
    if @workshop_variation.save
      flash[:notice] = 'Workshop Variation has been created.'
      if params[:from] == "workshop_show"
        redirect_to workshop_path(@workshop_variation.workshop, anchor: "workshop-variations")
      elsif params[:from] == "index"
        redirect_to workshop_variations_path
      else
        redirect_to authenticated_root_path
      end
    else
      set_form_variables
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
    set_form_variables
  end

  def update
    @workshop_variation = WorkshopVariation.find(params[:id])

    if @workshop_variation.update(workshop_variation_params)
      flash[:notice] = 'Workshop Variation updated successfully.'
      redirect_to workshop_variations_path
    else
      flash[:alert] = 'Unable to update Workshop Variation.'
      set_form_variables
      render :edit
    end
  end

  private

  def set_form_variables
    @workshop_variation.build_main_image if @workshop_variation.main_image.blank?
    @workshop_variation.gallery_images.build
  end

  def workshop_variation_params
    params.require(:workshop_variation).permit(
      [:name, :code, :inactive, :ordering,
       :youtube_url, :created_by_id, :workshop_id,
       main_image_attributes: [:id, :file, :_destroy],
       gallery_images_attributes: [:id, :file, :_destroy]
      ]
    )
  end

end
