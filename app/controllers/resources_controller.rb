class ResourcesController < ApplicationController
  include ExternallyRedirectable, AhoyTracking, TagAssignable
  skip_before_action :authenticate_user!, only: [ :index, :show ]

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 18
      base_scope = authorized_scope(Resource.includes(:bookmarks, primary_asset: :file_attachment,
                                                      downloadable_asset: :file_attachment)
                                            .where(kind: Resource::PUBLISHED_KINDS)) # TODO - #FIXME brittle
      filtered = base_scope.search_by_params(params).by_featured_first.order(created_at: :desc)

      @resources = filtered.paginate(page: params[:page], per_page: per_page)

      total_count    = base_scope.size
      filtered_count = filtered.size
      @count_display = filtered_count == total_count ? total_count : "#{filtered_count}/#{total_count}"

      track_index_intent(Resource, @resources, params)

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
    @resource = Resource.includes(created_by: :person).find(resource_id_param).decorate
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
      :created_by,
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
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
      Rails.logger.error "Resource create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @resource
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
    @resource.created_by ||= current_user
    success = false

    Resource.transaction do
      if @resource.update(resource_params)
        assign_associations(@resource)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
      Rails.logger.error "Resource update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      flash[:notice] = "Resource updated."
      redirect_to @resource
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
      elsif params[:from] == "home_index"
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
    @authors = authorized_scope(User.has_access.or(User.where(id: @resource.author_id)))
                   .includes(:person)
                   .map { |u| [ u.full_name, u.id ] }.sort_by(&:first)
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:position, :name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || (type.published? && !type.story_specific? && !type.profile_specific?) }
        .sort_by { |type, _| type&.name.to_s.downcase }
    @sectors = Sector.published.order(:name)
  end

  def resource_id_param
    params[:id]
  end

  def resource_params
    params.require(:resource).permit(
      :rhino_body, :kind, :male, :female, :title, :featured, :published, :publicly_visible, :publicly_featured,
      :agency, :author, :author_id, :filemaker_code, :windows_type_id, :position,
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
      @user_form = Report.new(created_by: current_user, owner: @resource)
      form.form_fields.where(status: 1).each do |field|
        @user_form.report_form_field_answers.build(form_field: field)
      end
    end
  end
end
