class StoryIdeasController < ApplicationController
  before_action :set_story_idea, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25


    story_ideas = StoryIdea.includes(:windows_type, :project, :workshop, :created_by, :updated_by)
    @story_ideas = story_ideas.order(created_at: :desc)
                              .paginate(page: params[:page], per_page: per_page)

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
    @story_idea.build_main_image if @story_idea.main_image.blank?
    @story_idea.gallery_images.build

    @user = User.find(params[:user_id]) if params[:user_id].present?
    @projects = (@user || current_user).projects.order(:name)
    @windows_types = WindowsType.all
    @workshops = Workshop.all.order(:title)
    @users = User.active.or(User.where(id: @story_idea.created_by_id))
                 .order(:first_name, :last_name)
  end

  # def remove_image
  #   @story_idea = StoryIdea.find(params[:id])
  #   @image = @story_idea.images.find(params[:image_id])
  #   @image.purge
  #
  #   respond_to do |format|
  #     format.turbo_stream
  #     format.html { redirect_to edit_story_path(@story_idea), notice: "Image removed." }
  #   end
  # end

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
      main_image_attributes: [:id, :file, :_destroy],
      gallery_images_attributes: [:id, :file, :_destroy]
    )
  end
end
