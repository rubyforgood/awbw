class StoryIdeasController < ApplicationController
  include AssetUpdatable

  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_story_idea, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(StoryIdea.includes(:windows_type, :organization, :workshop, :created_by, :updated_by))
    @story_ideas = base_scope.order(created_at: :desc)
                             .paginate(page: params[:page], per_page: per_page)
                             .decorate
    @story_ideas_count = base_scope.size
  end

  def show
    authorize! @story_idea
  end

  def new
    @story_idea = StoryIdea.new
    authorize! @story_idea

    set_form_variables
  end

  def edit
    authorize! @story_idea

    set_form_variables
  end

  def create
    @story_idea = StoryIdea.new(story_idea_params)
    @story_idea.created_by = current_user
    @story_idea.updated_by = current_user
    authorize! @story_idea

    if @story_idea.save
      NotificationServices::CreateNotification.call(
        noticeable: @story_idea,
        kind: :idea_submitted_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0)

      if params.dig(:library_asset, :new_assets).present?
        update_asset_owner(@story_idea)
      end

      flash[:notice] = "StoryIdea was successfully created."
      if allowed_to?(:index?, StoryIdea)
        redirect_to story_ideas_path
      else
        redirect_to root_path
      end
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    @story_idea.updated_by = current_user
    authorize! @story_idea

    if @story_idea.update(story_idea_params.except(:images))
      flash[:notice] = "StoryIdea was successfully updated."
      if allowed_to?(:index?, StoryIdea)
        redirect_to story_ideas_path, status: :see_other
      else
        redirect_to root_path, status: :see_other
      end
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @story_idea

    @story_idea.destroy!
    redirect_to story_ideas_path, notice: "StoryIdea was successfully destroyed."
  end

  # ---------------------------------------------------------

  def set_form_variables
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @organizations = (@user || current_user)&.organizations&.order(:name) || Organization.none
    @windows_types = WindowsType.all
    @workshops = Workshop.order(:title)

    @users = User.active.includes(:facilitator)
    @users = @users.or(User.where(id: @story_idea.created_by_id)) if @story_idea&.created_by_id
    @users = @users.distinct.order("facilitators.first_name, facilitators.last_name")
  end

  private

  def set_story_idea
    @story_idea = StoryIdea.find(params[:id])
  end

  def story_idea_params
    params.require(:story_idea).permit(
      :title, :body, :youtube_url,
      :permission_given, :publish_preferences, :promoted_to_story,
      :windows_type_id, :organization_id, :workshop_id, :external_workshop_title
    )
  end
end
