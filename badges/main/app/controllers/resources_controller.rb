class ResourcesController < ApplicationController
  include ExternallyRedirectable
  def index
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      unfiltered = Resource.where(kind: Resource::PUBLISHED_KINDS) # TODO - #FIXME brittle
        .includes(:main_image, :gallery_images, :attachments)
      filtered = unfiltered.search_by_params(params)
        .by_created
      @resources = filtered.paginate(page: params[:page], per_page: per_page)

      total_count = unfiltered.count
      filtered_count = filtered.count
      @count_display = if filtered_count == total_count
                         total_count
                       else
                         "#{filtered_count}/#{total_count}"
                       end

      render :resource_results
    else
      render :index
    end
  end

  def stories
    @stories = Resource.story.paginate(page: params[:page], per_page: 6).decorate
  end

  def new
    @resource = Resource.new.decorate
    set_form_variables
  end

  def edit
    @resource = Resource.find(resource_id_param).decorate
    set_form_variables
  end

  def show
    @resource = Resource.find(resource_id_param).decorate
    @resource.increment_view_count!(session: session, request: request)
    load_forms

    if @resource.external_url.present?
      redirect_to_external @resource.link_target
      return
    end
  end

  def rhino_text
    @resource = Resource.find(resource_id_param).decorate
    load_forms
    render :show_test
  end

  def create
    @resource = current_user.resources.build(resource_params)
    if @resource.save
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
    @resource.user ||= current_user
    if @resource.update(resource_params)
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
    @resource.destroy!
    redirect_to resources_path, notice: "Resource was successfully destroyed."
  end

  def search
    process_search
    @sortable_fields = Resource::PUBLISHED_KINDS
    render :index
  end

  def download
    @resource = Resource.find(params[:resource_id])
    @resource.increment!(:download_count)

    attachment = if params[:attachment_id].to_i > 0
      Attachment.where(owner_type: "Resource", id: params[:attachment_id]).last
    else
      Resource.find(params[:resource_id]).download_attachment
    end

    if attachment&.file&.blob.present?
      redirect_to rails_blob_url(attachment.file, disposition: "attachment")
    else
      if params[:from] == "resources_index"
        path = resources_path
      elsif params[:from] == "dashboard_index"
        path = authenticated_root_path
      else
        resource_path(params[:resource_id])
      end
      redirect_to path,
        alert: "File not found or not attached."
    end
  end

  private

  def set_form_variables
    @resource.build_main_image if @resource.main_image.blank?
    @resource.gallery_images.build

    @windows_types = WindowsType.all
    @authors = User.active.or(User.where(id: @resource.user_id))
      .order(:first_name, :last_name)
      .map { |u| [u.full_name, u.id] }
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
      :text, :rhino_text, :kind, :male, :female, :title, :featured, :inactive, :url,
      :agency, :author, :filemaker_code, :windows_type_id, :ordering,
      main_image_attributes: [:id, :file, :_destroy],
      gallery_images_attributes: [:id, :file, :_destroy],
      categorizable_items_attributes: [:id, :category_id, :_destroy], category_ids: [],
      sectorable_items_attributes: [:id, :sector_id, :is_leader, :_destroy], sector_ids: []
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
