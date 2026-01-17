 class LibraryAssetsController < ApplicationController
   before_action :set_asset, only: [ :show, :edit, :update, :destroy ]

   def show
     if @asset.file.attached?
       redirect_to rails_blob_url(@asset.file, disposition: "inline")
     else
       render plain: "File not attached", status: :not_found
     end
   end

   def create
     @owner = GlobalID::Locator.locate_signed(params[:owner_sgid])

     @asset = @owner.assets.build(asset_params.except(:file))
     if asset_params[:file].present?
       @asset.file.attach(asset_params[:file])
     end

     if @asset.save
       render partial: "assets/form"
     else
       render plain: @asset.errors.full_messages.join(", "), status: :unprocessable_entity
     end
    rescue NameError, ActiveRecord::RecordNotFound
      render plain: "Invalid Record", status: :unprocessable_entity
   end

   def edit
     render template: "assets/edit"
   end

   def update
     if @asset.update(asset_params)
       flash.now[:notice] = "Asset updated."
       render partial: "assets/title", locals: { asset: @asset }
     else
       flash[:alert] = "Failed to update asset."
       render :edit, status: :unprocessable_content
     end
   end

   def destroy
     @asset.destroy
     redirect_to root_path, notice: "Asset deleted"
   end

    private

   def set_asset
     @asset = Asset.find(params[:id])
   rescue ActiveRecord::RecordNotFound
     render plain: "Asset not found", status: :not_found
   end

   def asset_params
     params.expect(library_asset: [ :type, :title, :file ])
   end
 end
