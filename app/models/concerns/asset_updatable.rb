module AssetUpdatable
  extend ActiveSupport::Concern

  included do
    def validate_asset_type_constraint(asset_type, assets_collection)
      case asset_type
      when "PrimaryAsset"
        return false if assets_collection.any? { |a| a.is_a?(PrimaryAsset) }
      when "ThumbnailAsset"
        return false if assets_collection.any? { |a| a.is_a?(ThumbnailAsset) }
      end
      true
    end

    private

    def new_assets_params
      params
        .require(:library_asset)
        .permit(new_assets: [ :id, :type ])[:new_assets] || []
    end

    def update_asset_owner(resource)
      new_assets_params.each do |asset|
        asset = asset.to_h.symbolize_keys
        record = Asset.find_by(id: asset[:id])
        next unless record

        record.update(owner: resource)
      end
    end
  end
end
