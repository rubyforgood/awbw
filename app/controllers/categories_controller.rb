class CategoriesController < ApplicationController
  include AhoyTracking, Dedupable
  before_action :set_category, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25

    base_scope = authorized_scope(Category.includes(:category_type).joins(:category_type))
    filtered = base_scope.category_type_id(params[:category_type_id])
                         .category_name(params[:category_name])
                         .published(params[:published])
                         .order(Arel.sql("category_types.name, categories.position, categories.name"))
    @categories = filtered.paginate(page: params[:page], per_page: per_page)

    @count_display =
      if filtered.count == base_scope.count
        base_scope.count
      else
        "#{filtered.count}/#{base_scope.count}"
      end
    set_index_variables
  end

  def show
    authorize! @category
  end

  def new
    @category = Category.new
    authorize! @category
    set_form_variables
  end

  def edit
    authorize! @category
    set_form_variables
  end

  def create
    @category = Category.new(category_params)
    authorize! @category

    if @category.save
      redirect_to categories_path, notice: "Category was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @category
    respond_to do |format|
      if @category.update(category_params)
        format.html { redirect_to categories_path, notice: "Category was successfully updated.", status: :see_other }
        format.json { head :ok }
      else
        format.html do
          set_form_variables
          render :edit, status: :unprocessable_content
        end
        format.json { render json: { errors: @category.errors }, status: :unprocessable_content }
      end
    end
  end

  def destroy
    authorize! @category
    @category.destroy!
    redirect_to categories_path, notice: "Category was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @category_types = CategoryType.order(:name)
  end

  def set_index_variables
    @category_types = CategoryType.order(:name)
  end

  private

  def dedupe_config
    {
      model_class: Category,
      domain: :categories,
      belongs_to_options: -> { { "category_type_id" => CategoryType.order(:name) } },
      record_extras: ->(record) { "Type: #{record.category_type&.name || 'None'}" }
    }
  end

  def set_category
    @category = Category.find(params[:id])
  end

  # Strong parameters
  def category_params
    if params[:category]
      params.require(:category).permit(
        :name, :category_type_id, :published, :position
      )
    else
      params.permit(:position)
    end
  end
end
