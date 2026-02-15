class CategoriesController < ApplicationController
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

  def dedupe_index
    authorize!
    @possible_duplicates = find_possible_duplicates
    @categories_for_select = Category.order(:name).map { |c| [ c.name, c.id ] }
  end

  def dedupe_preview
    authorize!
    @category_to_delete = Category.find(params[:category_to_delete_id])
    @category_to_keep = Category.find(params[:category_to_keep_id])
    
    # Get associated records for comparison
    @delete_categorizable_items = @category_to_delete.categorizable_items.includes(:categorizable)
    @keep_categorizable_items = @category_to_keep.categorizable_items.includes(:categorizable)
    
    render :dedupe_preview
  end

  def dedupe_execute
    authorize!
    category_to_delete_id = params[:category_to_delete_id]
    category_to_keep_id = params[:category_to_keep_id]
    
    category_to_delete = Category.find(category_to_delete_id)
    category_to_keep = Category.find(category_to_keep_id)
    
    # Use the deduper service to perform the merge
    logger = Logger.new(StringIO.new)
    deduper = CategoryDeduper.new(logger: logger, dry_run: false, min_usage: 0)
    
    # Manually call merge for these specific categories
    usage_by_category_id = CategorizableItem.group(:category_id).count
    deduper.send(:merge_duplicate, category_to_keep, category_to_delete, usage_by_category_id)
    
    redirect_to categories_path, notice: "Categories merged successfully. '#{category_to_delete.name}' was merged into '#{category_to_keep.name}'."
  rescue StandardError => e
    redirect_to dedupe_index_categories_path, alert: "Error merging categories: #{e.message}"
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @category_types = CategoryType.order(:name)
  end

  def set_index_variables
    @category_types = CategoryType.order(:name)
  end

  private

  def find_possible_duplicates
    # Group categories by normalized name to find duplicates
    groups = Category.all.group_by { |c| c.name.to_s.strip.downcase }
    groups.select { |_name, categories| categories.size > 1 }
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
