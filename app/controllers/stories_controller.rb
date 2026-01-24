class StoriesController < ApplicationController
  include ExternallyRedirectable, AssetUpdatable, AhoyViewTracking
  before_action :set_story, only: [ :show, :edit, :update, :destroy ]

  def index
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 12
      unpaginated = current_user.super_user? ? Story.all : Story.published
      filtered = unpaginated.includes(:windows_type, :project, :workshop, :created_by, :bookmarks, :primary_asset)
                            .search_by_params(params)
                            .order(created_at: :desc)
      @stories = filtered.paginate(page: params[:page], per_page: per_page).decorate

      @count_display = if filtered.count == unpaginated.count
        unpaginated.count
      else
        "#{filtered.count}/#{unpaginated.count}"
      end
      render :index_lazy
    else
      render :index
    end
  end

  def show
    @story = @story.decorate
    track_view(@story)

    if @story.external_url.present? && !params[:no_redirect].present?
      redirect_to_external @story.link_target
      nil
    end
  end

  def new
    @story = Story.new.decorate
    @story = @story.decorate
    set_form_variables
  end

  def edit
    @story = @story.decorate
    set_form_variables
    if turbo_frame_request?
      render :editor_lazy
    else
      render :edit
    end
  end

  def create
    @story = Story.new(story_params)

    if @story.save
      if params.dig(:library_asset, :new_assets).present?
        update_asset_owner(@story)
      end

      redirect_to stories_path, notice: "Story was successfully created."
    else
      @story = @story.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @story.update(story_params.except(:images))
      redirect_to stories_path, notice: "Story was successfully updated.", status: :see_other
    else
      @story = @story.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @story.destroy!
    redirect_to stories_path, notice: "Story was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @story.build_primary_asset if @story.primary_asset.blank?
    @story.gallery_assets.build

    @story_idea = StoryIdea.find(params[:story_idea_id]) if params[:story_idea_id].present?
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @projects = (@user || current_user).projects.order(:name)
    @story_ideas = StoryIdea.includes(:created_by)
                            .references(:users)
                            .order(:created_at)
    @windows_types = WindowsType.all
    @workshops = Workshop.all.order(:title)
    @users = User.active.or(User.where(id: @story.created_by_id))
                 .order(:first_name, :last_name)
  end


  private

  def set_story
    @story = Story.find(params[:id])
  end

  # Strong parameters
  def story_params
    params.require(:story).permit(
      :title, :rhino_body, :featured, :published, :youtube_url, :website_url,
      :windows_type_id, :project_id, :workshop_id, :external_workshop_title,
      :created_by_id, :updated_by_id, :story_idea_id, :spotlighted_facilitator_id,
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
      new_assets: [ :id, :type ]
    )
  end
end
