class TutorialsController < ApplicationController
  include AhoyTracking
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_tutorial, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(Tutorial.all)
      filtered = base_scope.search_by_params(params)

      @count_display = filtered.size == base_scope.size ? base_scope.size : "#{filtered.count}/#{base_scope.count}"
      @tutorials = filtered.order(:position).paginate(page: params[:page], per_page: per_page).decorate

      render :index_lazy
    else
      @sectors = Sector.published.order(:name)
      @category_types = CategoryType.published.where(story_specific: false).order(:name).decorate

      render :index
    end
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

    success = false

    Tutorial.transaction do
      if @tutorial.save
        assign_associations(@tutorial)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Tutorial create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @tutorial, notice: "Video was successfully created."
    else
      @tutorial = @tutorial.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @tutorial

    success = false

    Tutorial.transaction do
      if @tutorial.update(tutorial_params)
        assign_associations(@tutorial)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Tutorial update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @tutorial, notice: "Video was successfully updated.", status: :see_other
    else
      @tutorial = @tutorial.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @tutorial
    @tutorial.destroy!
    redirect_to tutorials_path, notice: "Video was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @tutorial.build_primary_asset if @tutorial.primary_asset.blank?
    @tutorial.gallery_assets.build
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:position, :name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || type.published? }
        .sort_by { |type, _| type&.name.to_s.downcase }
    @sectors = Sector.published.order(:name)
  end

  private

  def set_tutorial
    @tutorial = Tutorial.find(params[:id])
  end

  def assign_associations(tutorial)
    selected_category_ids = Array(params[:tutorial][:category_ids]).reject(&:blank?).map(&:to_i)
    tutorial.categories = Category.where(id: selected_category_ids)

    selected_sector_ids = Array(params[:tutorial][:sector_ids]).reject(&:blank?).map(&:to_i)
    tutorial.sectors = Sector.where(id: selected_sector_ids)
    tutorial.save!
  end

  # Strong parameters
  def tutorial_params
    params.require(:tutorial).permit(
      :title, :body, :rhino_body, :position, :youtube_url,
      :featured, :published, :publicly_visible, :publicly_featured,
      category_ids: [],
      sector_ids: [],
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
    )
  end
end
