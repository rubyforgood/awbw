class VideoRecordingsController < ApplicationController
  include AhoyTracking, TagAssignable
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_video_recording, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    @video_type = params[:video_type].presence || "not_tutorials"
    @hide_search = params[:hide_search].present?

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 6
      base_scope = filter_by_video_type(authorized_scope(VideoRecording.all))
      filtered = base_scope.search_by_params(params)

      @count_display = filtered.size == base_scope.size ? base_scope.size : "#{filtered.count}/#{base_scope.count}"
      @video_recordings = filtered.order(:position).paginate(page: params[:page], per_page: per_page).decorate

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
      base_scope = authorized_scope(VideoRecording.where(is_instructional: false))
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
    @video_recording = @video_recording.decorate
    authorize! @video_recording
    track_view(@video_recording)
  end

  def new
    @video_recording = VideoRecording.new.decorate
    authorize! @video_recording
    set_form_variables
  end

  def edit
    @video_recording = @video_recording.decorate
    authorize! @video_recording
    set_form_variables
  end

  def create
    @video_recording = VideoRecording.new(video_recording_params)
    authorize! @video_recording

    success = false

    VideoRecording.transaction do
      if @video_recording.save
        assign_associations(@video_recording)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "VideoRecording create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @video_recording, notice: "VideoRecording was successfully created."
    else
      @video_recording = @video_recording.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @video_recording

    success = false

    VideoRecording.transaction do
      if @video_recording.update(video_recording_params)
        assign_associations(@video_recording)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "VideoRecording update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @video_recording, notice: "VideoRecording was successfully updated.", status: :see_other
    else
      @video_recording = @video_recording.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @video_recording
    @video_recording.destroy!
    redirect_to video_recordings_path, notice: "VideoRecording was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @video_recording.build_primary_asset if @video_recording.primary_asset.blank?
    @video_recording.gallery_assets.build
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

  def set_video_recording
    @video_recording = VideoRecording.find(params[:id])
  end

  def filter_by_video_type(scope)
    case @video_type
    when "tutorials"
      scope.instructional
    when "not_tutorials"
      scope.where(is_instructional: false)
    else
      scope
    end
  end

  # Strong parameters
  def video_recording_params
    params.require(:video_recording).permit(
      :title, :body, :rhino_body, :position, :youtube_url, :is_instructional, :is_podcast,
      :featured, :published, :publicly_visible, :publicly_featured,
      category_ids: [],
      sector_ids: [],
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
    )
  end
end
