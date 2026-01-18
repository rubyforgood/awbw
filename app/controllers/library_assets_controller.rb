 class LibraryAssetsController < ApplicationController
   include ActionView::RecordIdentifier

   before_action :set_asset, only: [ :show, :edit, :update, :destroy ]
   before_action :set_owner, only: [ :create, :update ]

   def show
     if @asset.file.attached?
       redirect_to rails_blob_url(@asset.file, disposition: "inline")
     else
       render plain: "File not attached", status: :not_found
     end
   end

   def create
     @asset = @owner ? @owner.assets.build(asset_params.except(:file)) : Asset.new(asset_params.except(:file))
     @unpersisted_owner = Data.define(:assets).new([])
     if params[:library_asset][:new_assets].present?
       params[:library_asset][:new_assets].each do |asset|
         @unpersisted_owner.assets << Asset.find_by(id: asset[:id])
       end
     end
     @asset.file.attach(asset_params[:file]) if asset_params[:file].present?
     if @asset.save
       if @owner
         render partial: "assets/form", locals: { asset: @asset, owner: @owner }
       else
         @unpersisted_owner.assets << @asset
         render template: "assets/create", formats: [ :turbo_stream ]
       end
     else
       flash.now[:alert] = @asset.errors.full_messages.join(", ")
       render turbo_stream: turbo_stream.replace("flash_now", partial: "shared/flash_messages", status: :unprocessable_entity)
     end
   end

   def edit
     render template: "assets/edit"
   end

   def update
     if @asset.update(asset_params)
       flash.now[:notice] = "Asset updated."
       case turbo_frame_request_id
       when "title_asset_#{ @asset.id }"
         render partial: "assets/title", locals: { asset: @asset }
       when "type_selector_asset_#{ @asset.id }"
         if @owner
           flash.now[:notice] = "Asset type updated!"
           render partial: "assets/form", locals: { asset: @asset, owner: @owner }
         else

           flash.now[:notice] = "Asset type updated!"
           render partial: "assets/type_selector", locals: { asset: @asset }
         end
       else
         redirect_back_or_to root_path
       end
     else
       flash.now[:alert] = @asset.errors.full_messages.join(", ")
       case turbo_frame_request_id
       when "type_selector_asset_#{ @asset.id }"
         if @owner
           render partial: "assets/form", locals: { asset: @asset, owner: @owner }
         else
           render partial: "assets/type_selector", locals: { asset: @asset }
         end
       else
         render turbo_stream: turbo_stream.replace("flash_now", partial: "shared/flash_messages", status: :unprocessable_entity)
       end
     end
   end

   def destroy
     @asset.destroy
     redirect_to root_path, notice: "Asset deleted"
   end

    private

   def set_asset
     @asset = Asset.find(params[:id])
   end

   def set_owner
     @owner = GlobalID::Locator.locate_signed(params[:owner_sgid]) if params[:owner_sgid]
   end

   def asset_params
     params.expect(library_asset: [ :type, :title, :file ])
   end
 end
