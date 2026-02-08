class WorkshopVariationsController < ApplicationController
  include AssetUpdatable, AhoyTracking
  def index
    authorize!

    base_scope = WorkshopVariation.includes(:workshop).joins(:workshop).where(workshops: { published: true })
    filtered = base_scope.order("workshop_variations.created_at DESC, workshops.title, workshop_variations.name")
    @workshop_variations = filtered.paginate(page: params[:page], per_page: 25).decorate
  end

  def new
    @workshop_variation = WorkshopVariation.new
    authorize! @workshop_variation
    set_form_variables
  end

  def create
    @workshop_variation = WorkshopVariation.new(workshop_variation_params)
    authorize! @workshop_variation

    if @workshop_variation.save
      NotificationServices::CreateNotification.call(
        noticeable: @workshop_variation,
        kind: :idea_submitted_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0)

      if params.dig(:library_asset, :new_assets).present?
        update_asset_owner(@workshop_variation)
      end

      flash[:notice] = "Workshop Variation has been created."
      if params[:from] == "workshop_show"
        redirect_to workshop_path(@workshop_variation.workshop, anchor: "workshop-variations")
      elsif params[:from] == "index"
        redirect_to workshop_variations_path
      else
        redirect_to root_path
      end
    else
      set_form_variables
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

  def set_form_variables
    workshops = current_user&.super_user? ? Workshop.all : Workshop.published
    @workshops = workshops.order(:title)
    @workshop = @workshop_variation.workshop || params[:workshop_id].present? &&
      Workshop.where(id: params[:workshop_id]).last
  end

  def workshop_variation_params
    params.require(:workshop_variation).permit(
      [ :name, :body, :published, :position,
       :youtube_url, :created_by_id, :workshop_id
      ]
    )
  end
end
