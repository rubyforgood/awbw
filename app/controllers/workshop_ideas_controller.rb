class WorkshopIdeasController < ApplicationController
  before_action :set_workshop_idea, only: [ :show, :edit, :update, :destroy ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    workshop_ideas = WorkshopIdea.search(params.slice(:title, :author_name))
    @workshop_ideas_count = workshop_ideas.size
    @workshop_ideas = workshop_ideas.paginate(page: params[:page], per_page: per_page).decorate
  end

  def show
  end

  def new
    @workshop_idea = WorkshopIdea.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @workshop_idea = WorkshopIdea.new(workshop_idea_params)

    if @workshop_idea.save
      NotificationServices::CreateNotification.call(
        noticeable: @workshop_idea,
        kind: :idea_submitted_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0)
      redirect_to workshop_ideas_path, notice: "Workshop idea was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @workshop_idea.update(workshop_idea_params)
      redirect_to workshop_ideas_path, notice: "Workshop idea was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @workshop_idea.destroy!
    redirect_to workshop_ideas_path, notice: "Workshop idea was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @workshop_idea.build_primary_asset if @workshop_idea.primary_asset.blank?
    @workshop_idea.gallery_assets.build

    @age_ranges = Category.includes(:category_type).where("metadata.name = 'AgeRange'").pluck(:name)
    @potential_series_workshops = Workshop.published.order(:title)
    @category_types = CategoryType.includes(:categories).published.decorate
    @sectors = Sector.published
    @windows_types = WindowsType.all
  end

  private

  def set_workshop_idea
    @workshop_idea = WorkshopIdea.find(params[:id])
  end

  # Strong parameters
  def workshop_idea_params
    params.require(:workshop_idea).permit(
      :title, :staff_notes,
      :created_by_id, :updated_by_id, :windows_type_id,
      :time_closing, :time_creation, :time_demonstration,
      :time_hours, :time_intro, :time_minutes,
      :time_opening, :time_opening_circle, :time_warm_up,

      :age_range, :age_range_spanish,
      :closing, :closing_spanish,
      :creation, :creation_spanish,
      :demonstration, :demonstration_spanish,
      :description, :description_spanish,
      :instructions, :instructions_spanish,
      :introduction, :introduction_spanish,
      :materials, :materials_spanish,
      :notes, :notes_spanish,
      :objective, :objective_spanish,
      :opening_circle, :opening_circle_spanish,
      :optional_materials, :optional_materials_spanish,
      :setup, :setup_spanish,
      :tips, :tips_spanish,
      :timeframe, :timeframe_spanish,
      :visualization, :visualization_spanish,
      :warm_up, :warm_up_spanish,

      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
      workshop_series_children_attributes: [ :id, :workshop_child_id, :workshop_parent_id, :theme_name,
                                            :series_description, :series_description_spanish,
                                            :position, :_destroy ],
    )
  end
end
