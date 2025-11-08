class StoriesController < ApplicationController
  before_action :set_story, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25

    stories = Story.includes(:windows_type, :project, :workshop, :created_by, :updated_by)
    @stories = stories.order(created_at: :desc)
                      .paginate(page: params[:page], per_page: per_page)

    @stories_count = stories.size
  end

  def show
  end

  def new
    @story = Story.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @story = Story.new(story_params)

    if @story.save
      redirect_to stories_path, notice: "Story was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @story.update(story_params.except(:images))
      # Attach new images *in addition* to existing ones
      if story_params[:images].present?
        @story.images.attach(story_params[:images])
      end
      redirect_to stories_path, notice: "Story was successfully updated.", status: :see_other
    else
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
    @story_idea = StoryIdea.find(params[:story_idea_id]) if params[:story_idea_id].present?
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @projects = (@user || current_user).projects.order(:name)
    @story_ideas = StoryIdea.includes(:created_by)
                            .references(:users)
                            .order(:created_at)
    @windows_types = WindowsType.all.order(:name)
    @workshops = Workshop.all.order(:title)
    @users = User.all.order(:first_name, :last_name)
  end

  # def remove_image
  #   @story = Story.find(params[:id])
  #   @image = @story.images.find(params[:image_id])
  #   @image.purge
  #
  #   respond_to do |format|
  #     format.turbo_stream
  #     format.html { redirect_to edit_story_path(@story), notice: "Image removed." }
  #   end
  # end

  private

  def set_story
    @story = Story.find(params[:id])
  end

  # Strong parameters
  def story_params
    params.require(:story).permit(
      :title, :body, :youtube_url, :published,
      :windows_type_id, :project_id, :workshop_id,
      :created_by_id, :updated_by_id, :story_idea_id, :spotlighted_facilitator_id,
      :main_image, images: []
    )
  end
end
