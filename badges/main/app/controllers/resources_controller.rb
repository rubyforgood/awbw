class ResourcesController < ApplicationController

  def index
    unpaginated = Resource.where(kind: ['Template','Handout', 'Scholarship',
                                        'Toolkit', 'Form', 'Resource', 'Story']) #TODO - #FIXME brittle
                          .includes(:images, :attachments)
                          .search_by_params(params)
                          .by_created
    @resources = unpaginated.paginate(page: params[:page], per_page: 24)

    @resources_count = unpaginated.size
    @sortable_fields = Resource::KINDS

    respond_to do |format|
      format.html
    end
  end

  def stories
    @stories = Resource.story.paginate(page: params[:page], per_page: 6)
  end

  def new
    @resource = Resource.new
  end

  def edit
    @resource = Resource.find(resource_id_param).decorate
  end

  def show
    @resource = Resource.find(resource_id_param).decorate
    load_forms
    render :show
  end

  def create
    @resource = current_user.resources.build(resource_params)
    if @resource.save
      redirect_to resources_path
    else
      flash[:alert] = "Unable to save #{@resource.title.titleize}"
      render :new
    end
  end

  def update
    @resource = Resource.find(params[:id])
    @resource.user ||= current_user
    if @resource.update(resource_params)
      flash[:notice] = 'Resource updated.'
      redirect_to resources_path
    else
      flash[:alert] = 'Failed to update Resource.'
      render :edit
    end
  end


  def search
    process_search
    @sortable_fields = Resource::KINDS.dup.delete("Story")
    render :index
  end

  def download
    attachment = Resource.find(params[:resource_id]).main_attachment
    if attachment&.file&.blob.present?
      redirect_to rails_blob_url(attachment.file, disposition: "attachment")
    else
      path = params[:from] == "resources_index" ? resources_path : resource_path(params[:resource_id])
      redirect_to path,
                  alert: "File not found or not attached."
    end
  end

  private

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
      :text, :kind, :male, :female, :title, :featured, :inactive, :url,
      :agency, :author, :filemaker_code, :windows_type_id, :ordering,
      categorizable_items_attributes: [:id, :category_id, :_destroy], category_ids: [],
      sectorable_items_attributes: [:id, :sector_id, :_destroy], sector_ids: [],
      images_attributes: [:file, :owner_id, :owner_type, :id, :_destroy],
      attachments_attributes: [:file, :owner_id, :owner_type, :id, :_destroy]
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
