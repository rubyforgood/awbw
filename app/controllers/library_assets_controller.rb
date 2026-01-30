 class LibraryAssetsController < ApplicationController
   include ActionView::RecordIdentifier, AssetUpdatable

   before_action :set_asset, only: [ :show, :edit, :update, :destroy ]
   before_action :set_owner, only: [ :create, :update ]

   def show
     if @asset&.file.attached?
       redirect_to rails_blob_url(@asset.file, disposition: "inline")
     else
       render plain: "File not attached", status: :not_found
     end
   end

   def create
     if @owner
       valid_asset = validate_asset_type_constraint(asset_params[:type], @owner.assets)

       unless valid_asset
         flash.now[:alert] = "Only one Primary or Downloadable asset allowed."
         return render partial: "assets/form", locals: { owner: @owner }
       end

       @asset = @owner.assets.build(asset_params.except(:file))
       @asset.file.attach(asset_params[:file]) if asset_params[:file].present?
       if @asset.save
         render partial: "assets/form", locals: { asset: @asset, owner: @owner }
       else
         flash.now[:alert] = @asset.errors.full_messages.join(", ")

         render turbo_stream: turbo_stream.replace(
           "flash_now",
           partial: "shared/flash_messages",
           status: :unprocessable_content
         )
       end
     else
       @unpersisted_owner = Data.define(:assets, :owner_class).new([], params[:owner_class])
       @asset =  Asset.new(asset_params.except(:file))
       @asset.file.attach(asset_params[:file]) if asset_params[:file].present?

       if params.dig(:library_asset, :new_assets).present?
         params[:library_asset][:new_assets].each do |asset|
           @unpersisted_owner.assets << Asset.find_by(id: asset[:id])
         end
       end
       valid_asset = validate_asset_type_constraint(@asset.type, @unpersisted_owner.assets)

       if valid_asset && @asset.save
         @unpersisted_owner.assets << @asset
         @unpersisted_owner.assets.compact!
         render template: "assets/create", formats: [ :turbo_stream ]
       else
         flash.now[:alert] = "Only one Primary or Downloadable asset allowed."
         render template: "assets/create", formats: [ :turbo_stream ]
       end
     end
   end

   def edit
     if @asset
       render template: "assets/edit"
     else
       flash.now[:alert] = "Error"
       redirect_back_or_to root_path
     end
   end

   def update
     valid_asset = @owner.present? ? validate_asset_type_constraint(asset_params[:type], @owner.assets) : true
     if  valid_asset && @asset&.update(asset_params)
       flash.now[:notice] = "Asset updated."
       case turbo_frame_request_id
       when "title_asset_#{@asset.id}"
         render partial: "assets/title", locals: { asset: @asset }
       when "type_selector_asset_#{@asset.id}"
         render partial: "assets/form", locals: { asset: @asset, owner: @owner.reload }
       end
     else

       messages = @asset.errors.full_messages

       unless valid_asset
         messages << "Only one Primary or Downloadable asset allowed."
       end

       flash.now[:alert] = messages.join(", ")
       case turbo_frame_request_id
       when "type_selector_asset_#{@asset.id}"
         render partial: "assets/form", locals: { asset: @asset, owner: @owner }
       else
         render turbo_stream: turbo_stream.replace(
           "flash_now",
           partial: "shared/flash_messages",
           status: :unprocessable_content
         )
       end
     end
   end

   def destroy
     if @asset
       @asset.destroy
       render turbo_stream: turbo_stream.remove(@asset)
     else
       flash.now[:alert] = "Error"
       redirect_back_or_to root_path
     end
   end

    private

   def set_asset
     @asset = Asset.includes(:file_attachment).find_by(id: params[:id])
   end

   def set_owner
     @owner = GlobalID::Locator.locate_signed(params[:owner_sgid]) if params[:owner_sgid]
   end

   def asset_params
     params.expect(library_asset: [ :type, :title, :file ])
   end
 end
