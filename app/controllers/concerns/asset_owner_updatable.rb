module AssetOwnerUpdatable
  extend ActiveSupport::Concern

  included do
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
