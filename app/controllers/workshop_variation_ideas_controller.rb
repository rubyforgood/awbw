class WorkshopVariationIdeasController < ApplicationController
  before_action :set_workshop_variation_idea, only: [ :show, :edit, :update, :destroy ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    workshop_variation_ideas = WorkshopVariationIdea.includes(:workshop, :created_by, :updated_by)
    @workshop_variation_ideas_count = workshop_variation_ideas.size
    @workshop_variation_ideas = workshop_variation_ideas.order(created_at: :desc)
                                                        .paginate(page: params[:page], per_page: per_page)
                                                        .decorate
  end

  def show
  end

  def new
    @workshop_variation_idea = WorkshopVariationIdea.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @workshop_variation_idea = WorkshopVariationIdea.new(workshop_variation_idea_params)

    if @workshop_variation_idea.save
      NotificationServices::CreateNotification.call(
        noticeable: @workshop_variation_idea,
        kind: :idea_submitted_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0)
      redirect_to workshop_variation_ideas_path, notice: "Workshop variation idea was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @workshop_variation_idea.update(workshop_variation_idea_params)
      redirect_to workshop_variation_ideas_path, notice: "Workshop variation idea was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @workshop_variation_idea.destroy!
    redirect_to workshop_variation_ideas_path, notice: "Workshop variation idea was successfully destroyed."
  end

  private

  def set_workshop_variation_idea
    @workshop_variation_idea = WorkshopVariationIdea.find(params[:id])
  end

  def set_form_variables
    @workshop_variation_idea.build_primary_asset if @workshop_variation_idea.primary_asset.blank?
    @workshop_variation_idea.gallery_assets.build

    @workshops = Workshop.published.order(:title)
    @users = User.active.or(User.where(id: @workshop_variation_idea.created_by_id))
                 .order(:first_name, :last_name)
  end

  def workshop_variation_idea_params
    params.require(:workshop_variation_idea).permit(
      :name, :description, :youtube_url,
      :inactive, :position,
      :workshop_id,
      :created_by_id, :updated_by_id,
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ]
    )
  end
end
