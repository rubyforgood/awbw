class AssetsController < ApplicationController
  before_action :set_asset, only: :update

  # Admin-only library of every asset (image/PDF/file) in the system, searchable
  # by keyword (title, filename, attached-to type) and filterable by asset type
  # and the model it's attached to.
  def index
    authorize! Asset, to: :index?, with: AssetPolicy

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 24
      base = Asset.includes(:owner, file_attachment: :blob)
      base = base.where(type: params[:type]) if params[:type].present?
      base = base.where(owner_type: params[:owner_type]) if params[:owner_type].present?
      base = base.where(id: Asset.joins(:file_blob).where(active_storage_blobs: { content_type: params[:content_type] })) if params[:content_type].present?
      base = base.searchable if params[:visibility] == "searchable"
      base = base.hidden if params[:visibility] == "hidden"

      filtered = base.search(params[:query]).order(created_at: :desc)
      @assets = filtered.paginate(page: params[:page], per_page: per_page)

      total_count    = base.count
      filtered_count = filtered.count
      @count_display = filtered_count == total_count ? total_count : "#{filtered_count}/#{total_count}"

      render :assets_results
    else
      @types         = Asset.present_types
      @owner_types   = Asset.present_owner_types
      @content_types = Asset.present_content_types
      render :index
    end
  end

  # New library asset. Defaults to hidden_from_search so a freshly uploaded asset
  # isn't surfaced until an admin deliberately unhides it.
  def new
    authorize! Asset, to: :new?, with: AssetPolicy
    @asset = Asset.new(type: Asset::TYPES.first, hidden_from_search: true)
  end

  def create
    authorize! Asset, to: :create?, with: AssetPolicy

    @asset = asset_class.new(create_params.except(:file, :type))
    @asset.file.attach(create_params[:file]) if create_params[:file].present?

    if @asset.save
      redirect_to asset_library_path, notice: "Asset added to the library."
    else
      render :new, status: :unprocessable_content
    end
  end

  # Inline edit of an asset's caption (title) and/or download filename from the
  # library. The two fields submit as independent turbo frames; whichever field
  # changed is present in the params.
  def update
    authorize! @asset, to: :update?, with: AssetPolicy

    @asset.title = params.dig(:asset, :title) if params[:asset]&.key?(:title)
    rename_file(params.dig(:asset, :filename))

    status = @asset.save ? :ok : :unprocessable_content
    render partial: "assets/editable_fields", locals: { asset: AssetDecorator.decorate(@asset.reload) }, status: status
  end

  private

  # STI subclass to instantiate, constrained to the known TYPES so a stray param
  # can't constantize into an arbitrary class.
  def asset_class
    type = create_params[:type].presence_in(Asset::TYPES) || Asset::TYPES.first
    type.constantize
  end

  def create_params
    params.require(:asset).permit(:type, :title, :hidden_from_search, :file)
  end

  def rename_file(filename)
    return if filename.blank? || !@asset.file.attached?

    @asset.file.blob.update(filename: filename)
  end

  def set_asset
    @asset = Asset.find(params[:id])
  end
end
