class BookmarksController < ApplicationController
  before_action :set_breadcrumb

  def index
    bookmarks = Bookmark.search(params)
    @bookmarks = bookmarks.paginate(page: params[:page], per_page: 25)
    @bookmarks_count = bookmarks.size
    @windows_types_array = WindowsType::TYPES
    load_sortable_fields
    respond_to do |format|
      format.html
      format.js
    end
  end

  def personal
    user = User.where(id: params[:user_id]).first if params[:user_id].present?
    user ||= current_user
    @user_name = user.full_name if user
    @viewing_self = user == current_user
    bookmarks = Bookmark.search(params, user: user)
    @bookmarks_count = bookmarks.size
    @bookmarks = bookmarks.paginate(page: params[:page], per_page: 25)
    @windows_types_array = WindowsType::TYPES

    load_sortable_fields
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @bookmark = current_user.bookmarks.find_or_create_by(bookmark_params)
    @bookmarkable = @bookmark.bookmarkable
    @bookmarkable.update(led_count: @bookmarkable.led_count + 1) if @bookmarkable.has_attribute?(:led_count)
    respond_to do |format|
      format.html {
        redirect_to authenticated_root_path, notice: "#{@bookmark.bookmarkable_type} added to your bookmarks."
      }
      format.turbo_stream do
        flash.now[:notice] = "#{@bookmark.bookmarkable_type} added to your bookmarks."
        render :update
      end
    end
  end

  def show
    @bookmark = Bookmark.find(params[:id]).decorate
    @bookmarkable = @bookmark.bookmarkable
    load_workshop_data if @bookmark.bookmarkable_class_name == "Workshop"
  end

  def destroy
    @bookmark = Bookmark.find(params[:id])
    if @bookmark
      @bookmark.destroy
      @bookmarkable = @bookmark.bookmarkable
      @bookmarkable.update(led_count: @bookmarkable.led_count - 1) if @bookmarkable.has_attribute?(:led_count)
      respond_to do |format|
        format.html {
          redirect_to authenticated_root_path, notice: "Bookmark has been deleted."
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

  def tally
    bookmark_ids = Bookmark.filter_by_params(params).pluck(:id)

    # Aggregate counts cleanly
    grouped_counts = Bookmark.where(id: bookmark_ids)
      .group(:bookmarkable_type, :bookmarkable_id)
      .pluck(:bookmarkable_type, :bookmarkable_id,
        Arel.sql("COUNT(*) AS total_bookmarks"))

    # Resolve polymorphic objects + sort desc
    @bookmark_counts = grouped_counts.group_by(&:first).flat_map do |type, rows|
      ids = rows.map { |_, id, _| id }
      found = type.constantize.where(id: ids).index_by(&:id)

      rows.filter_map do |(_, id, count)|
        [found[id], count] if found[id]
      end
    end.sort_by { |_, count| -count }

    @windows_types_array = WindowsType::TYPES

    @workshops = Workshop.where("led_count > 0").order(led_count: :desc)
  end

  private

  def load_sortable_fields
    @sortable_fields = WindowsType.where("name NOT LIKE ?", "%COMBINED%")
    @windows_types = WindowsType.all
  end

  def load_workshop_data
    @quotes = @bookmarkable.quotes
    @leader_spotlights = @bookmarkable.leader_spotlights
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
