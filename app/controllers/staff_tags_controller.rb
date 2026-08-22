class StaffTagsController < ApplicationController
  before_action :set_staff_tag, only: [ :show, :edit, :update, :destroy, :archive, :unarchive ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(StaffTag.all)
    @count_display = base_scope.count
    @staff_tags = base_scope.ordered.paginate(page: params[:page], per_page: per_page).decorate
    # Precompute tagged-people counts for the page in one grouped query so the
    # index doesn't fire a COUNT per row.
    @tagged_people_counts = StaffTagging
      .where(staff_tag_id: @staff_tags.map(&:id), staff_taggable_type: "Person")
      .group(:staff_tag_id)
      .count
  end

  def show
    @staff_tag = @staff_tag.decorate
    authorize! @staff_tag
  end

  def new
    @staff_tag = StaffTag.new.decorate
    authorize! @staff_tag
  end

  def edit
    @staff_tag = @staff_tag.decorate
    authorize! @staff_tag
  end

  def create
    @staff_tag = StaffTag.new(staff_tag_params)
    @staff_tag.created_by = current_user
    @staff_tag.updated_by = current_user
    authorize! @staff_tag

    if @staff_tag.save
      redirect_to @staff_tag, notice: "Staff tag was successfully created."
    else
      @staff_tag = @staff_tag.decorate
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @staff_tag
    @staff_tag.updated_by = current_user

    if @staff_tag.update(staff_tag_params)
      redirect_to @staff_tag, notice: "Staff tag was successfully updated.", status: :see_other
    else
      @staff_tag = @staff_tag.decorate
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @staff_tag

    if @staff_tag.destroy
      redirect_to staff_tags_path, notice: "Staff tag was successfully deleted.", status: :see_other
    else
      redirect_to staff_tags_path, alert: "Can't delete a staff tag that's still in use — archive it instead.", status: :see_other
    end
  end

  def archive
    authorize! @staff_tag
    @staff_tag.archive!
    redirect_to staff_tags_path, notice: "Staff tag was archived.", status: :see_other
  end

  def unarchive
    authorize! @staff_tag
    @staff_tag.unarchive!
    redirect_to staff_tags_path, notice: "Staff tag was unarchived.", status: :see_other
  end

  private

  def set_staff_tag
    @staff_tag = StaffTag.find(params[:id])
  end

  def staff_tag_params
    params.require(:staff_tag).permit(:name, :description)
  end
end
