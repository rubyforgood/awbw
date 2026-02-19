class WorkshopIdeasController < ApplicationController
  before_action :set_workshop_idea, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(WorkshopIdea.includes(:workshops))
    filtered = base_scope.search(params.slice(:title, :author_name))
    @workshop_ideas_count = filtered.size
    @workshop_ideas = filtered.paginate(page: params[:page], per_page: per_page).decorate
  end

  def show
    authorize! @workshop_idea
  end

  def new
    @workshop_idea = WorkshopIdea.new
    authorize! @workshop_idea
    set_form_variables
  end

  def create
    @workshop_idea = WorkshopIdea.new(workshop_idea_params)
    authorize! @workshop_idea

    if @workshop_idea.save
      NotificationServices::CreateNotification.call(
        noticeable: @workshop_idea,
        kind: :idea_submitted_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0)

      flash[:notice] = "Workshop idea was successfully created."
      if allowed_to?(:index?, WorkshopIdea)
        redirect_to @workshop_idea
      else
        redirect_to root_path
      end
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @workshop_idea
    set_form_variables
  end


  def update
    authorize! @workshop_idea
    if @workshop_idea.update(workshop_idea_params)
      redirect_to @workshop_idea, notice: "Workshop idea was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @workshop_idea
    @workshop_idea.destroy!
    redirect_to workshop_ideas_path, notice: "Workshop idea was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @age_ranges = Category.includes(:category_type).where("category_types.name = 'AgeRange'").pluck(:name)
    @potential_series_workshops = authorized_scope(Workshop.published).includes(:windows_type).order(:title)
    @sectors = Sector.published
    @windows_types = WindowsType.all
    @authors = User.has_access.includes(:person).sort_by { |u| u.name.downcase }
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:position, :name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || (type.published? && !type.story_specific?) }
        .sort_by { |type, _| type&.name.to_s.downcase }
    @workshop_idea.build_primary_asset if @workshop_idea.primary_asset.blank?
    @workshop_idea.gallery_assets.build
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

      :rhino_objective,
      :rhino_materials,
      :rhino_optional_materials,
      :rhino_setup,
      :rhino_introduction,
      :rhino_opening_circle,
      :rhino_demonstration,
      :rhino_warm_up,
      :rhino_visualization,
      :rhino_creation,
      :rhino_closing,
      :rhino_notes,
      :rhino_tips,
      :rhino_misc1,
      :rhino_misc2,
      :rhino_extra_field,

      :rhino_objective_spanish,
      :rhino_materials_spanish,
      :rhino_optional_materials_spanish,
      :rhino_age_range_spanish,
      :rhino_setup_spanish,
      :rhino_introduction_spanish,
      :rhino_opening_circle_spanish,
      :rhino_demonstration_spanish,
      :rhino_warm_up_spanish,
      :rhino_visualization_spanish,
      :rhino_creation_spanish,
      :rhino_closing_spanish,
      :rhino_notes_spanish,
      :rhino_tips_spanish,
      :rhino_misc1_spanish,
      :rhino_misc2_spanish,
      :rhino_extra_field_spanish,

      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],

      workshop_series_children_attributes: [ :id, :workshop_child_id, :workshop_parent_id, :theme_name,
                                            :series_description, :series_description_spanish,
                                            :position, :_destroy ],
    )
  end
end
