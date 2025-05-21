class BookmarksController < ApplicationController
  before_filter :set_breadcrumb

  def index
    @bookmarks = Bookmark.search(params, current_user).paginate(page: params[:page], per_page: 3)
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
    flash[:alert] = "#{@bookmark.bookmarkable_type} added to your bookmarks."
    redirect_to workshop_path(@bookmark.bookmarkable)
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
      flash[:alert] = 'Bookmark has been deleted.'
      redirect_to workshop_path(@bookmark.bookmarkable)
    else
      flash[:error] = 'Unable to find that bookmark.'
    end
  end

  private

  def load_sortable_fields
    @sortable_fields = WindowsType.where("name NOT LIKE ?", "%COMBINED%")
  end

  def load_workshop_data
    @quotes = @bookmarkable.quotes
    # @leader_spotlights = @bookmarkable.leader_spotlights
    @workshop_variations = @bookmarkable.workshop_variations.decorate
    @sectors = @bookmarkable.sectors
    @new_bookmark = @bookmarkable.bookmarks.build
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
