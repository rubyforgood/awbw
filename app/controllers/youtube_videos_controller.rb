class YoutubeVideosController < ApplicationController
  include AhoyTracking, TagAssignable
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_youtube_video, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 6
      base_scope = authorized_scope(YoutubeVideo.tutorials)
      filtered = base_scope.search_by_params(params)

      @count_display = filtered.size == base_scope.size ? base_scope.size : "#{filtered.count}/#{base_scope.count}"
      @youtube_videos = filtered.order(:position).paginate(page: params[:page], per_page: per_page).decorate

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
      base_scope = authorized_scope(YoutubeVideo.all)
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
    @youtube_video = @youtube_video.decorate
    authorize! @youtube_video
    track_view(@youtube_video)
  end

  def new
    @youtube_video = Tutorial.new.decorate
    authorize! @youtube_video
    set_form_variables
  end

  def edit
    @youtube_video = @youtube_video.decorate
    authorize! @youtube_video
    set_form_variables
  end

  def create
    @youtube_video = Tutorial.new(youtube_video_params)
    authorize! @youtube_video

    success = false

    YoutubeVideo.transaction do
      if @youtube_video.save
        assign_associations(@youtube_video)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Tutorial create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @youtube_video, notice: "YoutubeVideo was successfully created."
    else
      @youtube_video = @youtube_video.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @youtube_video

    success = false

    YoutubeVideo.transaction do
      if @youtube_video.update(youtube_video_params)
        assign_associations(@youtube_video)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Tutorial update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @youtube_video, notice: "YoutubeVideo was successfully updated.", status: :see_other
    else
      @youtube_video = @youtube_video.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @youtube_video
    @youtube_video.destroy!
    redirect_to tutorials_path, notice: "YoutubeVideo was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @youtube_video.build_primary_asset if @youtube_video.primary_asset.blank?
    @youtube_video.gallery_assets.build
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

  def set_youtube_video
    @youtube_video = YoutubeVideo.find(params[:id])
  end

  # Strong parameters
  def youtube_video_params
    params.require(:youtube_video).permit(
      :title, :body, :rhino_body, :position, :youtube_url, :is_tutorial, :is_podcast,
      :featured, :published, :publicly_visible, :publicly_featured,
      category_ids: [],
      sector_ids: [],
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
    )
  end
end
