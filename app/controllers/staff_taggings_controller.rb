class StaffTaggingsController < ApplicationController
  before_action :set_staff_tagging, only: [ :edit, :update, :destroy ]

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(StaffTagging.includes(:staff_tag, :created_by, :staff_taggable))
      filtered = base_scope.search_by_params(params.to_unsafe_h)
      @sort = %w[person staff_tag marked created_at].include?(params[:sort]) ? params[:sort] : "created_at"
      @sort_direction = params[:direction] == "asc" ? "asc" : "desc"
      filtered = case @sort
      when "person"
        filtered.joins("LEFT JOIN people ON people.id = staff_taggings.staff_taggable_id AND staff_taggings.staff_taggable_type = 'Person'")
                .reorder(Arel.sql("people.first_name #{@sort_direction}, people.last_name #{@sort_direction}"))
      when "staff_tag"
        filtered.left_joins(:staff_tag).reorder(Arel.sql("staff_tags.name #{@sort_direction}"))
      when "marked"
        filtered.reorder(marked: @sort_direction, created_at: :desc)
      else
        filtered.reorder(created_at: @sort_direction)
      end
      @count_display = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"
      @mark_column_label = mark_column_label
      @staff_taggings = filtered.paginate(page: params[:page], per_page: per_page)

      render :staff_taggings_results
    else
      render :index
    end
  end

  def new
    @staff_tagging = StaffTagging.new
    authorize! @staff_tagging
  end

  def create
    @staff_tagging = StaffTagging.new(create_params)
    authorize! @staff_tagging

    if @staff_tagging.save
      redirect_to staff_taggings_path, notice: "Staff tagging created.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @staff_tagging
  end

  def update
    authorize! @staff_tagging
    @staff_tagging.assign_attributes(staff_tagging_params)

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

  def create_params
    person = Person.find_by(id: params.dig(:staff_tagging, :person_id))
    { staff_tag_id: params.dig(:staff_tagging, :staff_tag_id), staff_taggable: person, marked: params.dig(:staff_tagging, :marked) == "1" }
  end

  # When the list is filtered to a single tag, the Mark column header takes that
  # tag's configured label; otherwise it stays the generic "Mark".
  def mark_column_label
    ids = Array(params[:staff_tag_ids]).reject(&:blank?)
    return "Mark" unless ids.one?

    StaffTag.where(id: ids).pick(:mark_label).presence || "Mark"
  end

  def staff_tagging_params
    params.require(:staff_tagging).permit(
      :staff_tag_id,
      :marked,
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
