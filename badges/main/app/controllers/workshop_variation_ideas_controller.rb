class WorkshopVariationIdeasController < ApplicationController
  include AhoyTracking
  before_action :set_workshop_variation_idea, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = WorkshopVariationIdea.includes(:workshop, :created_by, :updated_by)
    filtered = base_scope.search_by_params(params)
    @workshop_variation_ideas_count = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"
    @workshop_variation_ideas = filtered.order(created_at: :desc)
                                        .paginate(page: params[:page], per_page: per_page)
                                        .decorate
  end

  def show
    authorize! @workshop_variation_idea
    track_view(@workshop_variation_idea)

    @workshop = (@workshop_variation_idea.workshop || Workshop.where(id: params[:workshop_id]).last)&.decorate
    @bookmark = current_user.bookmarks.find_by(bookmarkable: @workshop)
    @new_bookmark = @workshop.bookmarks.build
    @quotes = @workshop.quotes
    @workshop_variation_ideas = WorkshopVariationIdea.where(workshop: @workshop)
    @sectors = @workshop.sectors
  end

  def new
    @workshop_variation_idea = WorkshopVariationIdea.new
    authorize! @workshop_variation_idea
    set_form_variables
  end

  def edit
    authorize! @workshop_variation_idea
    set_form_variables
  end

  def create
    @workshop_variation_idea = WorkshopVariationIdea.new(workshop_variation_idea_params)
    authorize! @workshop_variation_idea

    if @workshop_variation_idea.save
      NotificationServices::CreateNotification.call(
        noticeable: @workshop_variation_idea,
        kind: :idea_submitted_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0)

      flash[:notice] = "Workshop variation idea was successfully created."
      if allowed_to?(:index?, WorkshopVariationIdea)
        redirect_to workshop_variation_ideas_path
      else
        redirect_to root_path
      end
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @workshop_variation_idea
    if @workshop_variation_idea.update(workshop_variation_idea_params)
      redirect_to workshop_variation_ideas_path, notice: "Workshop variation idea was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @workshop_variation_idea
    @workshop_variation_idea.destroy!
    redirect_to workshop_variation_ideas_path, notice: "Workshop variation idea was successfully destroyed."
  end

  private

  def set_workshop_variation_idea
    @workshop_variation_idea = WorkshopVariationIdea.find(params[:id]).decorate
  end

  def set_form_variables
    @workshop_variation_idea.build_primary_asset if @workshop_variation_idea.primary_asset.blank?
    @workshop_variation_idea.gallery_assets.build

    @workshops = authorized_scope(Workshop.published).includes(:windows_type).order(:title)
    @organizations = authorized_scope(Organization.all).order(:name)
    @windows_types = WindowsType.order(:name)
    @users = authorized_scope(User.has_access.or(User.where(id: @workshop_variation_idea.created_by_id)))
                 .order(:first_name, :last_name)
  end

  def workshop_variation_idea_params
    params.require(:workshop_variation_idea).permit(
      :name, :body, :youtube_url,
      :permission_given, :publish_preferences,
      :organization_id, :windows_type_id, :workshop_id, :created_by_id, :updated_by_id,
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ]
    )
  end
end
