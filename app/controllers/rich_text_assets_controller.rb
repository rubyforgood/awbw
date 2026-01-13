 class RichTextAssetsController < ApplicationController
   before_action :set_rich_text_asset, only: [ :show, :destroy ]

   def show
     if @rich_text_asset.file.attached?
       redirect_to rails_blob_url(@rich_text_asset.file, disposition: "inline")
     else
       render plain: "File not attached", status: :not_found
     end
   end

   def create
     @owner = params[:owner_type].constantize.find(params[:owner_id])
     @rich_text_asset = @owner.rich_text_assets.build
     @rich_text_asset.file.attach(params[:file]) if params[:file].present?

     if @rich_text_asset.save
       redirect_to edit_polymorphic_path(@owner)
     else
       render plain: @rich_text_asset.errors.full_messages.join(", "), status: :unprocessable_entity
     end
   rescue NameError, ActiveRecord::RecordNotFound
     render plain: "Invalid Record", status: :unprocessable_entity
   end

   def destroy
     @rich_text_asset.destroy
     redirect_to root_path, notice: "Asset deleted"
   end

    private

   def set_rich_text_asset
     @rich_text_asset = RichTextAsset.find(params[:id])
   rescue ActiveRecord::RecordNotFound
     render plain: "RichTextAsset not found", status: :not_found
   end
 end
