class RecordingsController < ApplicationController
  include AhoyTracking, TagAssignable
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_recording, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 6
      base_scope = authorized_scope(Recording.tutorials)
      filtered = base_scope.search_by_params(params)

      @count_display = filtered.size == base_scope.size ? base_scope.size : "#{filtered.count}/#{base_scope.count}"
      @recordings = filtered.order(:position).paginate(page: params[:page], per_page: per_page).decorate

      render :index_lazy
    else
      @sectors = Sector.published.order(:name)
      @category_types = CategoryType.published.general.order(:name).decorate

      render :index
    end
  end

  def video_library
    authorize!
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 6
      base_scope = authorized_scope(Recording.all)
      filtered = base_scope.search_by_params(params)

      @count_display = filtered.size == base_scope.size ? base_scope.size : "#{filtered.count}/#{base_scope.count}"
      @video_library = filtered.order(:position).paginate(page: params[:page], per_page: per_page).decorate

      render :video_library_lazy
    else
      @sectors = Sector.published.order(:name)
      @category_types = CategoryType.published.general.order(:name).decorate

      render :video_library
    end
  end

  def show
    @recording = @recording.decorate
    authorize! @recording
    track_view(@recording)
  end

  def new
    @recording = Tutorial.new.decorate
    authorize! @recording
    set_form_variables
  end

  def edit
    @recording = @recording.decorate
    authorize! @recording
    set_form_variables
  end

  def create
    @recording = Tutorial.new(recording_params)
    authorize! @recording

    success = false

    Recording.transaction do
      if @recording.save
        assign_associations(@recording)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Tutorial create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @recording, notice: "Recording was successfully created."
    else
      @recording = @recording.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @recording

    success = false

    Recording.transaction do
      if @recording.update(recording_params)
        assign_associations(@recording)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Tutorial update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @recording, notice: "Recording was successfully updated.", status: :see_other
    else
      @recording = @recording.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @recording
    @recording.destroy!
    redirect_to tutorials_path, notice: "Recording was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @recording.build_primary_asset if @recording.primary_asset.blank?
    @recording.gallery_assets.build
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

  def set_recording
    @recording = Recording.find(params[:id])
  end

  # Strong parameters
  def recording_params
    params.require(:recording).permit(
      :title, :body, :rhino_body, :position, :youtube_url, :is_tutorial, :is_podcast,
      :featured, :published, :publicly_visible, :publicly_featured,
      category_ids: [],
      sector_ids: [],
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
    )
  end
end
