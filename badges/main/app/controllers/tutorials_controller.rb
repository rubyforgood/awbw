class TutorialsController < ApplicationController
  include AhoyTracking
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_tutorial, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(Tutorial.all)
    filtered = base_scope.search_by_params(params)

    @count_display = filtered.size == base_scope.size ? base_scope.size : "#{filtered.count}/#{base_scope.count}"
    @tutorials = filtered.order(:position).paginate(page: params[:page], per_page: per_page).decorate
  end

  def show
    @tutorial = @tutorial.decorate
    authorize! @tutorial
    track_view(@tutorial)
  end

  def new
    @tutorial = Tutorial.new.decorate
    authorize! @tutorial
    set_form_variables
  end

  def edit
    @tutorial = @tutorial.decorate
    authorize! @tutorial
    set_form_variables
  end

  def create
    @tutorial = Tutorial.new(tutorial_params)
    authorize! @tutorial

    if @tutorial.save
      redirect_to tutorials_path, notice: "Tutorial was successfully created."
    else
      @tutorial = @tutorial.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @tutorial
    if @tutorial.update(tutorial_params)
      redirect_to tutorials_path, notice: "Tutorial was successfully updated.", status: :see_other
    else
      @tutorial = @tutorial.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @tutorial
    @tutorial.destroy!
    redirect_to tutorials_path, notice: "Tutorial was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @tutorial.build_primary_asset if @tutorial.primary_asset.blank?
    @tutorial.gallery_assets.build
  end

  private

  def set_tutorial
    @tutorial = Tutorial.find(params[:id])
  end

  # Strong parameters
  def tutorial_params
    params.require(:tutorial).permit(
      :title, :body, :rhino_body, :position, :youtube_url,
      :featured, :published, :publicly_visible,
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
    )
  end
end
