class CategoriesController < ApplicationController
  before_action :set_category, only: [ :show, :edit, :update, :destroy ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    @category_types = CategoryType.order(:name)

    unfiltered = Category.joins(:category_type)
    filtered = unfiltered.category_type_id(params[:category_type_id])
                          .category_name(params[:category_name])
                          .published_search(params[:published_search])
                          .order(Arel.sql("category_types.name, categories.position, categories.name"))
    @categories = filtered.paginate(page: params[:page], per_page: per_page)

    @count_display = if filtered.count == unfiltered.count
      unfiltered.count
    else
      "#{filtered.count}/#{unfiltered.count}"
    end
  end

  def show
  end

  def new
    @category = Category.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to categories_path, notice: "Category was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
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
    @category.destroy!
    redirect_to categories_path, notice: "Category was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @category_types = CategoryType.order(:name)
  end

  private

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
