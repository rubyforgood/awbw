 class PrimaryAssetsController < ApplicationController
   include ActionView::RecordIdentifier
   before_action :set_owner, only: [ :create ]

   def create
     authorize! @owner # We are check the policy of the record that owns the asset, eg. can a user edit @workshop
     ActiveRecord::Base.transaction do
       if existing_primary = @owner.assets.find_by(type: "PrimaryAsset")
         existing_primary.update!(type: "GalleryAsset")
       end

       @asset = @owner.assets.build(asset_params.except(:file))
       @asset.type = "PrimaryAsset"
       @asset.file.attach(asset_params[:file]) if asset_params[:file].present?
       @asset.save!
     end

     redirect_back_or_to polymorphic_path(@owner)
   end


   private

   def set_owner
     @owner = GlobalID::Locator.locate_signed(params[:owner_sgid]) if params[:owner_sgid]
   end

   def asset_params
     params.expect(primary_asset: [ :file, :sgid ])
   end
 end
