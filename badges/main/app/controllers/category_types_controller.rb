class CategoryTypesController < ApplicationController
  before_action :set_category_type, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(CategoryType.all)
    @count_display = base_scope.count
    @category_types = base_scope.order(:name).paginate(page: params[:page], per_page: per_page).decorate
  end

  def show
    @category_type = @category_type.decorate
    authorize! @category_type
  end

  def new
    @category_type = CategoryType.new.decorate
    authorize! @category_type
  end

  def edit
    @category_type = @category_type.decorate
    authorize! @category_type
  end

  def create
    @category_type = CategoryType.new(category_type_params)
    authorize! @category_type

    if @category_type.save
      redirect_to category_types_path, notice: "Category type was successfully created."
    else
      @category_type = @category_type.decorate
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @category_type
    if @category_type.update(category_type_params)
      redirect_to category_types_path, notice: "Category type was successfully updated.", status: :see_other
    else
      @category_type = @category_type.decorate
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @category_type
    @category_type.destroy!
    redirect_to category_types_path, notice: "Category type was successfully destroyed."
  end

  private

  def set_category_type
    @category_type = CategoryType.find(params[:id])
  end

  def category_type_params
    params.require(:category_type).permit(:name, :display_text, :published, :story_specific)
  end
end
