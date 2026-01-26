class StoryIdeasController < ApplicationController
  include AssetUpdatable
  before_action :set_story_idea, only: [ :show, :edit, :update, :destroy ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25


    story_ideas = StoryIdea.includes(:windows_type, :project, :workshop, :created_by, :updated_by)
    @story_ideas = story_ideas.order(created_at: :desc)
                              .paginate(page: params[:page], per_page: per_page).decorate

    @story_ideas_count = story_ideas.size
  end

  def show
  end

  def new
    @story_idea = StoryIdea.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @story_idea = StoryIdea.new(story_idea_params)

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

      redirect_to story_ideas_path, notice: "StoryIdea was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @story_idea.update(story_idea_params.except(:images))
      redirect_to story_ideas_path, notice: "StoryIdea was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @story_idea.destroy!
    redirect_to story_ideas_path, notice: "StoryIdea was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @projects = (@user || current_user).projects.order(:name)
    @windows_types = WindowsType.all
    @workshops = Workshop.all.order(:title)
    @users = User.active.or(User.where(id: @story_idea.created_by_id))
                 .order(:first_name, :last_name)
  end

  private

  def set_story_idea
    @story_idea = StoryIdea.find(params[:id])
  end

  # Strong parameters
  def story_idea_params
    params.require(:story_idea).permit(
      :title, :body, :youtube_url,
      :permission_given, :publish_preferences, :promoted_to_story,
      :windows_type_id, :project_id, :workshop_id, :external_workshop_title,
      :created_by_id, :updated_by_id,
    )
  end
end
