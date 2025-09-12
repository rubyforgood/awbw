class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :bookmarkable, polymorphic: true
  has_many :bookmark_annotations, dependent: :destroy

  def self.sort_by_windows_type(bookmarks, windows_type_id)
    if windows_type_id == "3"
      workshops = Workshop.where(id: bookmarks.pluck{|b| b.bookmarkable_id}).order(windows_type_id: :desc)
    elsif windows_type_id == "1"
      workshops = Workshop.where(id: bookmarks.pluck{|b| b.bookmarkable_id}).order(windows_type_id: :asc)
    end

    workshops_ids = workshops.pluck{|w| w.id}
    bookmarks = bookmarks.where(bookmarkable_id: workshops_ids).order(:windows_type_id)
  end

  def self.search(params, user)
    bookmarks = user.bookmarks

    if params[:type].nil? || params[:type].empty?
      bookmarks = bookmarks.where(bookmarkable_type: "Workshop")
                           .joins("INNER JOIN workshops ON bookmarks.bookmarkable_id = workshops.id")
                           .order("workshops.title")
    end

    if params[:type] == "led"
      bookmarks = bookmarks.where(bookmarkable_type: "Workshop")
                           .joins("INNER JOIN workshops ON bookmarks.bookmarkable_id = workshops.id")
                           .order("workshops.led_count")
    end

    if params[:type] == "created"
      bookmarks = bookmarks.order(created_at: :desc)
    end

    if params[:type] == "3" || params[:type] == "1"
      bookmarks = sort_by_windows_type(bookmarks, params[:type]) 
    end

    bookmarks
  end
end
