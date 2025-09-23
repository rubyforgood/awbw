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

  def self.filter_by_windows_type_ids(windows_type_ids)
    bookmarks = self.all
    if windows_type_ids
      bookmarks = Bookmark
                    .where(bookmarkable_type: "Workshop")
                    .joins("INNER JOIN workshops ON workshops.id = bookmarks.bookmarkable_id")
                    .where("workshops.windows_type_id IN (?)", windows_type_ids)
                    .order(windows_type_id: :desc, title: :asc)
    end
    bookmarks
  end

  def self.filter_by_params(params={})
    bookmarks = self.all
    # filter by
    if params[:title].present?
      bookmarks = bookmarks
                    .where(bookmarkable_type: "Workshop")
                    .joins("INNER JOIN workshops ON workshops.id = bookmarks.bookmarkable_id")
                    .where("workshops.title LIKE ?", "%#{params[:title]}%")
    end
    if params[:windows_types].present?
      windows_type_ids = params[:windows_types].values.map(&:to_i)
      bookmarks = filter_by_windows_type_ids(windows_type_ids)
    end
    if params[:query].present?
      bookmarks = bookmarks.filter_by_query(params[:query])
    end
    bookmarks
  end

  def self.filter_by_query(query = nil)
    return all if query.blank?

    # Whitelisted, quoted column names to use in search
    cols = %w[title full_name objective materials introduction demonstration opening_circle
              warm_up creation closing notes tips misc1 misc2].
      map { |c| connection.quote_column_name(c) }.join(", ")
    # Prepare query for BOOLEAN MODE (prefix matching)
    terms = query.to_s.strip.split.map { |term| "#{term}*" }.join(" ")
    # Convert to Arel for safety
    match_expr = Arel.sql("MATCH(#{cols}) AGAINST(? IN BOOLEAN MODE)")

    joins(:bookmarkable).select(
      sanitize_sql_array(["workshops.*, #{match_expr.to_sql} AS all_score", terms])
    ).where(match_expr, terms)
  end

  def self.search(params, user)
    bookmarks = user.bookmarks
    bookmarks = bookmarks.filter_by_params(params)

    if params[:sort] == "title" || params[:sort].nil? || params[:sort].empty?
      bookmarks = bookmarks.where(bookmarkable_type: "Workshop")
                           .joins("INNER JOIN workshops ON bookmarks.bookmarkable_id = workshops.id")
                           .order("workshops.title")
    end

    if params[:sort] == "led"
      bookmarks = bookmarks.where(bookmarkable_type: "Workshop")
                           .joins("INNER JOIN workshops ON bookmarks.bookmarkable_id = workshops.id")
                           .order("workshops.led_count DESC")
    end

    if params[:sort] == "created"
      bookmarks = bookmarks.order(created_at: :desc)
    end

    if params[:sort] == "3" || params[:sort] == "1"
      bookmarks = sort_by_windows_type(bookmarks, params[:sort])
    end

    bookmarks
  end
end
