# When including this in a new model, be sure to add the following to the resource form
# <%= tag.div class: "unpersisted_resource_asset_params" %>
# The asset controller appends the correct id's to this div
#
# When the asset id's are submitted with the form, this concern updates the asset owner

module AssetUpdatable
  extend ActiveSupport::Concern

  included do
    def validate_asset_type_constraint(asset_type, assets_collection)
      case asset_type
      when "PrimaryAsset"
        return false if assets_collection.any? { |a| a.is_a?(PrimaryAsset) }
      when "DownloadableAsset"
        return false if assets_collection.any? { |a| a.is_a?(DownloadableAsset) }
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
