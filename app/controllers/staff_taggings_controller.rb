class StaffTaggingsController < ApplicationController
  before_action :set_staff_tagging, only: [ :edit, :update, :destroy ]

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(StaffTagging.includes(:staff_tag, :created_by, :staff_taggable))
      filtered = base_scope.search_by_params(params.to_unsafe_h)
                           .order(created_at: :desc)
      @count_display = filtered.count
      @staff_taggings = filtered.paginate(page: params[:page], per_page: per_page)

      render :staff_taggings_results
    else
      render :index
    end
  end

  def edit
    authorize! @staff_tagging
  end

  def update
    authorize! @staff_tagging
    @staff_tagging.assign_attributes(staff_tagging_params)
    @staff_tagging.comments.select(&:new_record?).each do |comment|
      comment.created_by = current_user
      comment.updated_by = current_user
    end
    @staff_tagging.comments.select { |comment| comment.persisted? && comment.body_changed? }.each do |comment|
      comment.updated_by = current_user
    end

    if @staff_tagging.save
      redirect_to staff_tagging_return_path, notice: "Staff tag updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @staff_tagging
    @staff_tagging.destroy
    redirect_to staff_taggings_path, notice: "Staff tagging was successfully removed.", status: :see_other
  end

  private

  def set_staff_tagging
    @staff_tagging = StaffTagging.find(params[:id])
  end

  def staff_tagging_params
    params.require(:staff_tagging).permit(
      :staff_tag_id,
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      notifications_attributes: [ :id, :channel, :sender_id, :email_subject, :email_body_text, :direction, :responded, :noticeable_type, :noticeable_id, :_destroy ]
    )
  end

  def staff_tagging_return_path
    case params[:return_to]
    when "staff_tag"
      staff_tag_path(@staff_tagging.staff_tag)
    when "staff_taggings"
      staff_taggings_path
    when "person"
      edit_person_path(params[:origin_id], anchor: helpers.dom_id(@staff_tagging), admin: params[:admin].presence)
    else
      person_return_path
    end
  end

  def person_return_path
    taggable = @staff_tagging.staff_taggable
    return staff_tag_path(@staff_tagging.staff_tag) unless taggable.is_a?(Person)

    edit_person_path(taggable, anchor: helpers.dom_id(@staff_tagging))
  end
end
