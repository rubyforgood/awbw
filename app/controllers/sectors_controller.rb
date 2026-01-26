class SectorsController < ApplicationController
  before_action :set_sector, only: [ :show, :edit, :update, :destroy ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unfiltered = Sector.all
    filtered = unfiltered.sector_name(params[:sector_name])
                          .published_search(params[:published_search])
                          .order(:name)
    @sectors = filtered.paginate(page: params[:page], per_page: per_page)

    @count_display = if filtered.count == unfiltered.count
      unfiltered.count
    else
      "#{filtered.count}/#{unfiltered.count}"
    end
  end

  def show
  end

  def new
    @sector = Sector.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @sector = Sector.new(sector_params)

    if @sector.save
      redirect_to sectors_path, notice: "Sector was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @sector.update(sector_params)
      redirect_to sectors_path, notice: "Sector was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @sector.destroy!
    redirect_to sectors_path, notice: "Sector was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
  end

  private

  def set_sector
    @sector = Sector.find(params[:id])
  end

  # Strong parameters
  def sector_params
    params.require(:sector).permit(
      :name, :published
    )
  end
end
