class GalleryAssetsController < ApplicationController
  before_action :set_gallery_asset, only: :update

  def index
    authorize! GalleryAsset
    @query = params[:query].to_s.strip

    scope = authorized_scope(GalleryAsset.images.with_attached_file.includes(:owner))
    scope = scope.search_metadata(@query) if @query.present?
    scope = scope.order(created_at: :desc)

    @count = scope.count
    @gallery_assets = scope.paginate(page: params[:page], per_page: 24)

    render :results if turbo_frame_request?
  end

  def update
    authorize! @gallery_asset
    @gallery_asset.update(gallery_asset_params)
    render partial: "gallery_assets/card", locals: { gallery_asset: @gallery_asset }
  end

  private

  def set_gallery_asset
    @gallery_asset = GalleryAsset.find(params[:id])
  end

  def gallery_asset_params
    params.expect(gallery_asset: [ :title ])
  end
end
