class ResourcesController < ApplicationController
  include ExternallyRedirectable, AhoyTracking
  skip_before_action :authenticate_user!, only: [ :index, :show ]

  def index
    authorize!

    per_page = params[:number_of_items_per_page].presence || 18
    base_scope = authorized_scope(Resource.includes(:bookmarks, primary_asset: :file_attachment,
                                                    downloadable_asset: :file_attachment)
                                          .where(kind: Resource::PUBLISHED_KINDS)) # TODO - #FIXME brittle
    filtered = base_scope.search_by_params(params).by_featured_first

    @resources = filtered.paginate(page: params[:page], per_page: per_page)

    total_count    = base_scope.size
    filtered_count = filtered.size
    @count_display = filtered_count == total_count ? total_count : "#{filtered_count}/#{total_count}"

    track_index_intent(Resource, @resources, params)

    if turbo_frame_request?
      render :resource_results
    else
      render :index
    end
  end

  def stories
    authorize!
    @stories = Resource.story.paginate(page: params[:page], per_page: 6).decorate
  end

  def new
    authorize!
    @resource = Resource.new.decorate
    set_form_variables
  end

  def edit
    @resource = Resource.includes(user: :person).find(resource_id_param).decorate
    authorize! @resource
    set_form_variables

    if turbo_frame_request?
      render :editor_lazy
    else
      render :edit
    end
  end

  def show
    @resource = Resource.includes(
      :user,
      :bookmarks,
      primary_asset:  :file_attachment,
      downloadable_asset:  :file_attachment,
      gallery_assets: :file_attachment,
    ).find(resource_id_param).decorate
    authorize! @resource
    track_view(@resource)
    @mentions = @resource.all_mentions_grouped
  end

  def create
    authorize!
    @resource = current_user.resources.build(resource_params)

    success = false

    Resource.transaction do
      if @resource.save
        assign_associations(@resource)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Resource create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to resources_path
    else
      @resource = @resource.decorate
      set_form_variables
      flash[:alert] = "Unable to save #{@resource.title.presence || 'resource'}"
      render :new, status: :unprocessable_content
    end
  end

  def update
    @resource = Resource.find(params[:id])
    authorize! @resource
    @resource.user ||= current_user
    success = false

    Resource.transaction do
      if @resource.update(resource_params)
        assign_associations(@resource)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Resource update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      flash[:notice] = "Resource updated."
      redirect_to resources_path
    else
      set_form_variables
      flash[:alert] = "Failed to update Resource."
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @resource = Resource.find(params[:id])
    authorize! @resource
    @resource.destroy!
    redirect_to resources_path, notice: "Resource was successfully destroyed."
  end

  def search
    authorize!
    process_search
    @sortable_fields = Resource::PUBLISHED_KINDS
    render :index
  end

  def download
    @resource = Resource.find(params[:resource_id])
    authorize! @resource

    attachment = @resource&.downloadable_asset&.file
    if attachment.attached?
      track_download(@resource)
      redirect_to rails_blob_url(attachment, disposition: "attachment")
    else
      if params[:from] == "resources_index"
        path = resources_path
      elsif params[:from] == "dashboard_index"
        path = root_path
      else
        resource_path(params[:resource_id])
      end
      redirect_to path,
        alert: "File not found or not attached."
    end
  end

  private

  def set_form_variables
    @resource.build_primary_asset if @resource.primary_asset.blank?
    @resource.build_downloadable_asset if @resource.downloadable_asset.blank?
    @resource.gallery_assets.build
    @windows_types = WindowsType.all
    @authors = User.active.or(User.where(id: @resource.user_id))
                   .includes(:person)
                   .order("people.first_name, people.last_name")
                   .map { |u| [ u.full_name, u.id ] }
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:position, :name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || type.published? }
        .sort_by { |type, _| type&.name.to_s.downcase }
    @sectors = Sector.published.order(:name)
  end

  def assign_associations(resource)
    selected_category_ids = Array(params[:resource][:category_ids]).reject(&:blank?).map(&:to_i)
    resource.categories = Category.where(id: selected_category_ids)

    selected_sector_ids = Array(params[:resource][:sector_ids]).reject(&:blank?).map(&:to_i)
    resource.sectors = Sector.where(id: selected_sector_ids)
    resource.save!
  end

  def process_search
    @params = search_params
    @query = search_params[:query]
    @resources = Search.new.search(search_params, current_user).paginate(page: params[:search][:page])
  end

  def resource_id_param
    params[:id]
  end

  def resource_params
    params.require(:resource).permit(
      :user_id,
      :rhino_body, :kind, :male, :female, :title, :featured, :published, :publicly_visible, :publicly_featured, :url,
      :agency, :author, :filemaker_code, :windows_type_id, :position,
      primary_asset_attributes: [ :id, :file, :_destroy ],
      downloadable_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
      categorizable_items_attributes: [ :id, :category_id, :_destroy ], category_ids: [],
      sectorable_items_attributes: [ :id, :sector_id, :is_leader, :_destroy ], sector_ids: []
    )
  end

  def load_forms
    form = @resource.form
    if form
      @user_form = Report.new(user: current_user, owner: @resource)
      form.form_fields.where(status: 1).each do |field|
        @user_form.report_form_field_answers.build(form_field: field)
      end
    end
  end

  def search_params
    params[:search]
  end
end
