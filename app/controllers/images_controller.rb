class ImagesController < ApplicationController
  before_action :set_image, only: :update

  # Admin-only index of every asset (image/file) in the system, searchable by
  # keyword (title, filename, attached-to type) and filterable by asset type
  # and the model it's attached to.
  def index
    authorize! Asset, to: :index?, with: AssetPolicy

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 24
      base = Asset.includes(:owner, file_attachment: :blob)
      base = base.where(type: params[:type]) if params[:type].present?
      base = base.where(owner_type: params[:owner_type]) if params[:owner_type].present?

      filtered = base.search(params[:query]).order(created_at: :desc)
      @images = filtered.paginate(page: params[:page], per_page: per_page)

      total_count    = base.count
      filtered_count = filtered.count
      @count_display = filtered_count == total_count ? total_count : "#{filtered_count}/#{total_count}"

      render :images_results
    else
      @types       = Asset.present_types
      @owner_types = Asset.present_owner_types
      render :index
    end
  end

  # Inline edit of an asset's title (label) from the index.
  def update
    authorize! @image, to: :update?, with: AssetPolicy

    status = @image.update(image_params) ? :ok : :unprocessable_content
    render partial: "images/title_field", locals: { image: AssetDecorator.decorate(@image) }, status: status
  end

  private

  def set_image
    @image = Asset.find(params[:id])
  end

  def image_params
    params.expect(asset: [ :title ])
  end
end
