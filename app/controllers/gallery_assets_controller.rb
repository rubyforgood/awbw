class GalleryAssetsController < ApplicationController
  before_action :set_asset, only: [ :destroy, :make_primary ]

  # Remove an image from the gallery
  def destroy
    authorize! @asset.owner, to: :manage? # check the policy of the record that owns the asset
    @asset.destroy!

    redirect_back_or_to polymorphic_path(@asset.owner), notice: "Image removed."
  end

  # Promote an existing gallery image to be the featured (primary) image
  def make_primary
    authorize! @asset.owner, to: :manage?
    ActiveRecord::Base.transaction do
      if existing_primary = @asset.owner.assets.find_by(type: "PrimaryAsset")
        existing_primary.update!(type: "GalleryAsset")
      end

      @asset.update!(type: "PrimaryAsset")
    end

    redirect_back_or_to polymorphic_path(@asset.owner), notice: "Featured image updated."
  end

  private

  def set_asset
    @asset = GalleryAsset.find(params[:id])
  end
end
