class ResourcesController < ApplicationController
  def index
    @resources = current_user.curriculum(Resource).by_created.search(params).
                    paginate(page: params[:page], per_page: 25)

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
    @sectors = Sector.pluck(:name, :id)
  end

  def edit
    @resource = Resource.find(resource_id_param).decorate
    @sectors = Sector.pluck(:name, :id)
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
      flash[:error] = "Unable to save #{@resource.title.titleize}"
      render :new
    end
  end

  def update
    @resource = Resource.find(params[:id])
    if @resource.update(resource_params)
      flash[:alert] = 'Resource updated.'
      redirect_to resources_path
    else
      flash[:error] = 'Failed to update Resource.'
      render :edit
    end
  end


  def search
    process_search
    @sortable_fields = Resource::KINDS.dup.delete("Story")
    render :index
  end

  def download
    attachment = Resource.find(params[:resource_id]).attachments.last
    extension = File.extname(attachment.file_file_name)
    send_data open("#{attachment.file.expiring_url(10000, :original)}").read, filename: "original_#{attachment.id}#{extension}", type: attachment.file_content_type
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
      categorizable_items_attributes: [:_create, :category_id],
      sectorable_items_attributes: [:_create, :sector_id],
      images_attributes: [:file, :owner_id, :owner_type, :id, :_destroy]
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
