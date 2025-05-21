class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :bookmarkable, polymorphic: true
  has_many :bookmark_annotations, dependent: :destroy

  def self.sort_by_windows_type(bookmarks, windows_type_id)
    if windows_type_id == "3"
      workshops = Workshop.where(id: bookmarks.map{|b| b.bookmarkable_id}).order(windows_type_id: :desc)
    elsif windows_type_id == "1"
      workshops = Workshop.where(id: bookmarks.map{|b| b.bookmarkable_id}).order(windows_type_id: :asc)
    end

    workshops_ids = workshops.map{|w| w.id}
    bookmarks = bookmarks.where(bookmarkable_id: workshops_ids).order("FIELD(bookmarkable_id, #{workshops_ids.join(',')})")
  end

  def self.search(params, user)
    bookmarks = user.bookmarks

    if params[:type].nil? || params[:type].empty?
      workshops = Workshop.where(id: bookmarks.map{|b| b.bookmarkable_id}).order(title: :asc)
      workshops_ids = workshops.map{|w| w.id}
      bookmarks = bookmarks.where(bookmarkable_id: workshops_ids).order("FIELD(bookmarkable_id, #{workshops_ids.join(',')})")
    end

    if params[:type] == "led"
      workshops = Workshop.where(id: bookmarks.map{|b| b.bookmarkable_id}).order(led_count: :desc)
      workshops_ids = workshops.map{|w| w.id}
      bookmarks = bookmarks.where(bookmarkable_id: workshops_ids).order("FIELD(bookmarkable_id, #{workshops_ids.join(',')})")
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
