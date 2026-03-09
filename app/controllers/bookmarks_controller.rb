class BookmarksController < ApplicationController
  before_action :set_breadcrumb

  VALID_SORTS = %w[created_at title popularity].freeze

  def index
    authorize!
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(Bookmark.includes(:bookmarkable))
      filtered = base_scope.search(params)
      @sort = VALID_SORTS.include?(params[:sort]) ? params[:sort] : "created_at"
      @sort_direction = params[:direction] == "asc" ? "asc" : "desc"
      filtered = filtered.sorted(@sort, @sort_direction)
      @bookmarks = filtered.paginate(page: params[:page], per_page: per_page).decorate
      @count_display = filtered.length == base_scope.length ? base_scope.length : "#{filtered.length}/#{base_scope.length}"
      set_index_variables
      render :index_lazy
    else
      set_index_variables
    end
  end

  def personal
    authorize!
    user = User.find_by(id: params[:user_id]) if params[:user_id].present?
    user ||= current_user
    @user_name = user.full_name if user
    @viewing_self = user == current_user

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(Bookmark.includes(:bookmarkable))
      filtered = base_scope.search(params, user: user)
      @sort = VALID_SORTS.include?(params[:sort]) ? params[:sort] : "created_at"
      @sort_direction = params[:direction] == "asc" ? "asc" : "desc"
      filtered = filtered.sorted(@sort, @sort_direction)
      user_base = base_scope.where(user: user)
      @bookmarks_count = filtered.length
      @bookmarks = filtered.paginate(page: params[:page], per_page: per_page)
      @count_display = filtered.length == user_base.length ? user_base.length : "#{filtered.length}/#{user_base.length}"
      set_index_variables
      render :personal_lazy
    else
      set_index_variables
    end
  end

  def tally
    authorize!
    bookmark_ids = Bookmark.filter_by_params(params).pluck(:id)

    # Aggregate counts cleanly
    base_scope = authorized_scope(Bookmark.all)
    grouped_counts = base_scope.where(id: bookmark_ids)
                               .group(:bookmarkable_type, :bookmarkable_id)
                               .pluck(:bookmarkable_type, :bookmarkable_id,
                                      Arel.sql("COUNT(*) AS total_bookmarks"))

    # Resolve polymorphic objects + sort desc
    @bookmark_counts = grouped_counts.group_by(&:first).flat_map do |type, rows|
      ids = rows.map { |_, id, _| id }
      found = type.constantize.where(id: ids).decorate.index_by(&:id)

      rows.filter_map do |(_, id, count)|
        [ found[id], count ] if found[id]
      end
    end.sort_by { |_, count| -count }

    set_index_variables
  end

  def create
    authorize! Bookmark
    @bookmark = current_user.bookmarks.find_or_create_by(bookmark_params)
    @bookmarkable = @bookmark.bookmarkable
    respond_to do |format|
      format.html {
        redirect_to root_path, notice: "#{@bookmark.bookmarkable_type} added to your bookmarks."
      }
      format.turbo_stream do
        flash.now[:notice] = "#{@bookmark.bookmarkable_type} added to your bookmarks."
        render :update
      end
    end
  end

  def show
    @bookmark = Bookmark.find(params[:id]).decorate
    authorize! @bookmark
    @bookmarkable = @bookmark.bookmarkable
    load_workshop_data if @bookmark.bookmarkable_class_name == "Workshop"
  end

  def destroy
    @bookmark = Bookmark.find(params[:id])
    authorize! @bookmark
    if @bookmark
      @bookmark.destroy
      current_user.bookmarks.reload
      @bookmarkable = @bookmark.bookmarkable
      respond_to do |format|
        format.html {
          redirect_to root_path, notice: "Bookmark has been deleted."
        }
        format.turbo_stream do
          flash.now[:notice] = "Bookmark has been deleted."
          render :update
        end
      end
    else
      flash[:alert] = "Unable to find that bookmark."
    end
  end

  private

  def set_index_variables
    @sortable_fields = WindowsType.where("name NOT LIKE ?", "%COMBINED%")
    @windows_types_array = WindowsType::TYPES
    @bookmarkable_types = Bookmark.bookmarkable_type_options
    @workshops = authorized_scope(Workshop.where("led_count > 0")).order(led_count: :desc)
    @users = User.has_access.includes(:person).references(:person).order(Arel.sql("LOWER(people.first_name), LOWER(people.last_name), LOWER(users.email), LOWER(people.email_2), LOWER(people.email)"))
  end

  def load_workshop_data
    @quotes = @bookmarkable.quotes
    @workshop_variations = @bookmarkable.workshop_variations.decorate
    @sectors = @bookmarkable.sectors
  end

  def bookmark_params
    params.require(:bookmark).permit(
      :bookmarkable_id, :bookmarkable_type
    )
  end

  def set_breadcrumb
    @breadcrumb = params[:breadcrumb]
  end
end
