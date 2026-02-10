class StoriesController < ApplicationController
  include ExternallyRedirectable, AhoyTracking
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_story, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 12
      base_scope = authorized_scope(Story.includes(:windows_type, :organization, :workshop, :created_by, :bookmarks, :primary_asset))
      filtered = base_scope.search_by_params(params)
                           .order(created_at: :desc)
      @stories = filtered.paginate(page: params[:page], per_page: per_page).decorate

      @count_display = if filtered.count == base_scope.count
        base_scope.count
      else
        "#{filtered.count}/#{base_scope.count}"
      end
      render :index_lazy
    else
      render :index
    end
  end

  def show
    @story = @story.decorate
    authorize! @story
    track_view(@story)

    if @story.external_url.present? && !params[:no_redirect].present?
      redirect_to_external @story.link_target
      nil
    end
  end

  def new
    if params[:story_idea_id].present?
      @story_idea = StoryIdea.find(params[:story_idea_id])
      @story = Story.new(set_story_attributes_from(@story_idea))
    else
      @story = Story.new
    end
    authorize! @story
    @story.decorate
    set_form_variables
  end

  def edit
    @story = @story.decorate
    authorize! @story
    set_form_variables
    if turbo_frame_request?
      render :editor_lazy
    else
      render :edit
    end
  end

  def create
    @story = Story.new(story_params)
    authorize! @story

    if @story.save
      if params[:promote_idea_assets] == "true"
        @story.attach_assets_from_idea!
      end

      redirect_to stories_path, notice: "Story was successfully created."
    else
      @story = @story.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @story
    if @story.update(story_params.except(:images))
      redirect_to stories_path, notice: "Story was successfully updated.", status: :see_other
    else
      @story = @story.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @story
    @story.destroy!
    redirect_to stories_path, notice: "Story was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @story_idea = StoryIdea.find(params[:story_idea_id]) if params[:story_idea_id].present?
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @organizations = (@user || current_user).organizations.order(:name)
    @story_ideas = StoryIdea.includes(:created_by)
                            .references(:users)
                            .order(:created_at)
    @windows_types = WindowsType.all
    @workshops = Workshop.all.order(:title)
    @users = User.active.or(User.where(id: @story.created_by_id))
                 .includes(:person)
                 .order("people.first_name, people.last_name")
    @story.build_primary_asset if @story.primary_asset.blank?
    @story.gallery_assets.build
  end


  private

  def set_story
    @story = Story.find(params[:id])
  end

  # Strong parameters
  def story_params
    params.require(:story).permit(
      :title, :rhino_body, :featured, :published, :publicly_visible, :public_featued, :youtube_url, :website_url,
      :windows_type_id, :organization_id, :workshop_id, :external_workshop_title,
      :created_by_id, :updated_by_id, :story_idea_id, :spotlighted_facilitator_id,
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ]
    )
  end

  def set_story_attributes_from(idea)
    {
      rhino_body: idea.body,
      organization_id: idea.organization.id,
      workshop_id: idea.workshop_id,
      external_workshop_title: idea.external_workshop_title,
      windows_type_id: idea.windows_type_id,
      youtube_url: idea.youtube_url
    }
  end
end
