class WorkshopIdeasController < ApplicationController
  before_action :set_workshop_idea, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    workshop_ideas = WorkshopIdea.search(params.slice(:title, :author_name))
    @workshop_ideas_count = workshop_ideas.size
    @workshop_ideas = workshop_ideas.paginate(page: params[:page], per_page: per_page)
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
    @potential_series_workshops = Workshop.published.order(:title)
    image = @workshop_idea.images.first || @workshop_idea.images.build # build an image if there isn't one

    @age_ranges = AgeRange.pluck(:name)
    @category_metadata = Metadatum.published.includes(:categories).decorate
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
      :title, :description, :staff_notes, :created_by_id, :updated_by_id, :windows_type_id,
      :tips, :objective, :materials, :introduction, :creation, :closing,
      :visualization, :warm_up, :opening_circle, :demonstration, :setup,
      :instructions, :optional_materials, :notes, :age_range,

      workshop_series_children_attributes: [:id, :workshop_child_id, :workshop_parent_id, :theme_name,
                                            :series_description, :series_description_spanish,
                                            :series_order, :_destroy],
    )
  end
end
