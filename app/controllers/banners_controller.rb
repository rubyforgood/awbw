class BannersController < ApplicationController
  before_action :set_banner, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unpaginated = Banner.all
    @banners_count = unpaginated.count
    @banners = unpaginated.paginate(page: params[:page], per_page: per_page)
  end

  def show
  end

  def new
    @banner = Banner.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @banner = Banner.new(banner_params)

    if @banner.save
      redirect_to banners_path, notice: "Banner was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @banner.update(banner_params)
      redirect_to banners_path, notice: "Banner was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @banner.destroy!
    redirect_to banners_path, notice: "Banner was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
  end

  private

  def set_banner
    @banner = Banner.find(params[:id])
  end

  # Strong parameters
  def banner_params
    params.require(:banner).permit(
      :content, :show, :created_by_id, :updated_by_id
    )
  end
end
