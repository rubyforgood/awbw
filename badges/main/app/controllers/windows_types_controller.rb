class WindowsTypesController < ApplicationController
  before_action :set_windows_type, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unpaginated = WindowsType.all
    @windows_types_count = unpaginated.count
    @windows_types = unpaginated.paginate(page: params[:page], per_page: per_page)
  end

  def show
  end

  def new
    @windows_type = WindowsType.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @windows_type = WindowsType.new(windows_type_params)

    # Convert checkbox values into categorizable_items updates
    selected_ids = Array(params[:windows_type][:category_ids]).reject(&:blank?).map(&:to_i)
    @windows_type.categories = Category.where(id: selected_ids)

    if @windows_type.save
      redirect_to windows_types_path, notice: "Windows type was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    # Convert checkbox values into categorizable_items updates
    selected_ids = Array(params[:windows_type][:category_ids]).reject(&:blank?).map(&:to_i)
    @windows_type.categories = Category.where(id: selected_ids)

    if @windows_type.update(windows_type_params)
      redirect_to windows_types_path, notice: "Windows type was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @windows_type.destroy!
    redirect_to windows_types_path, notice: "Windows type was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @categories = Category.age_ranges.order(:name)
    @windows_type.categorizable_items.build
  end

  private

  def set_windows_type
    @windows_type = WindowsType.find(params[:id])
  end

  # Strong parameters
  def windows_type_params
    params.require(:windows_type).permit(
      :name, :short_name, :legacy_id,
      category_ids: []
    )
  end
end
