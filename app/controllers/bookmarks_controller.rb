class BookmarksController < ApplicationController
  before_action :set_breadcrumb

  def index
    bookmarks = Bookmark.search(params)
    @bookmarks = bookmarks.paginate(page: params[:page], per_page: 25)
    @bookmarks_count = bookmarks.size

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
    @bookmarks = Bookmark.search(params, user: user).paginate(page: params[:page], per_page: 25)

    load_sortable_fields
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @bookmark = current_user.bookmarks.find_or_create_by(bookmark_params)
    @bookmarkable = @bookmark.bookmarkable
    @bookmarkable.update(led_count: @bookmarkable.led_count + 1)
    flash[:notice] = "#{@bookmark.bookmarkable_type} added to your bookmarks."
    if params[:from] == "workshops_index"
      redirect_to workshops_path(params.permit(:title, :query, :sort, :page, :active).to_h),
                  anchor: "workshop-#{@bookmark.bookmarkable.id}-anchor"
    else
      redirect_to workshop_path(@bookmark.bookmarkable)
    end

  end

  def show
    @bookmark = Bookmark.find(params[:id]).decorate
    @bookmarkable = @bookmark.bookmarkable
    load_workshop_data if @bookmark.bookmarkable_class_name == 'Workshop'
  end

  def destroy
    @bookmark = Bookmark.find(params[:id])
    if @bookmark
      @bookmark.destroy
      @bookmarkable = @bookmark.bookmarkable
      @bookmarkable.update(led_count: @bookmarkable.led_count - 1)
      flash[:notice] = 'Bookmark has been deleted.'
      if params[:from] == "index"
        redirect_to bookmarks_path
      elsif params[:from] == "workshops_index"
        redirect_to workshops_path(params.permit(:title, :query, :sort, :page, :active).to_h),
                    anchor: "workshop-#{@bookmark.bookmarkable.id}-anchor"
      else
        redirect_to workshop_path(@bookmark.bookmarkable)
      end
    else
      flash[:alert] = 'Unable to find that bookmark.'
    end
  end

  def tally
    search_params = params.to_unsafe_h.merge({ sort: "bookmark_count" })
    @bookmark_counts = Bookmark.search(search_params)
                               .group(:bookmarkable_type, :bookmarkable_id)
                               .order('count_id DESC')
                               .count('id')
                               .map{ |(type, id), count| [type.constantize.find(id), count] rescue nil}
                               .compact
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
