class TutorialsController < ApplicationController
  before_action :set_tutorial, only: [ :show, :edit, :update, :destroy ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unfiltered = current_user.super_user? ? Tutorial.all : Tutorial.published
    filtered = unfiltered.search_by_params(params)
    @count_display = filtered.count == unfiltered.count ? unfiltered.count : "#{filtered.count}/#{unfiltered.count}"
    @tutorials = filtered.order(:position).paginate(page: params[:page], per_page: per_page).decorate
  end

  def show
    @tutorial = @tutorial.decorate
    @tutorial.increment_view_count!(session: session, request: request)
  end

  def new
    @tutorial = Tutorial.new.decorate
    set_form_variables
  end

  def edit
    @tutorial = @tutorial.decorate
    set_form_variables
  end

  def create
    @tutorial = Tutorial.new(tutorial_params)

    if @tutorial.save
      redirect_to tutorials_path, notice: "Tutorial was successfully created."
    else
      @tutorial = @tutorial.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @tutorial.update(tutorial_params)
      redirect_to tutorials_path, notice: "Tutorial was successfully updated.", status: :see_other
    else
      @tutorial = @tutorial.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
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
      :title, :body, :rhino_body, :featured, :published, :position, :youtube_url,
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
    )
  end
end
