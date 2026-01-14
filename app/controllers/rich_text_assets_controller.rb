 class RichTextAssetsController < ApplicationController
   before_action :set_rich_text_asset, only: [ :show, :edit, :update, :destroy ]

   def show
     if @rich_text_asset.file.attached?
       redirect_to rails_blob_url(@rich_text_asset.file, disposition: "inline")
     else
       render plain: "File not attached", status: :not_found
     end
   end

   def create
     @owner = GlobalID::Locator.locate_signed(params[:owner_sgid])

     @rich_text_asset = @owner.rich_text_assets.build(title: params[:title])
     @rich_text_asset.file.attach(params[:file]) if params[:file].present?
     if @rich_text_asset.save
       render partial: "rich_text_assets/form"
     else
       render plain: @rich_text_asset.errors.full_messages.join(", "), status: :unprocessable_entity
     end
    rescue NameError, ActiveRecord::RecordNotFound
      render plain: "Invalid Record", status: :unprocessable_entity
   end
   def edit
     @rich_text_asset
   end

   def update
     if @rich_text_asset.update(rich_text_asset_params)
       flash.now[:notice] = "Asset updated."
       render partial: "title", locals: { asset: @rich_text_asset }
     else
       flash[:alert] = "Failed to update asset."
       render :edit, status: :unprocessable_content
     end
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

   def rich_text_asset_params
     params.expect(rich_text_asset: [ :title ])
   end
 end
