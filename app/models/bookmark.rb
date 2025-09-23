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
                    .joins("INNER JOIN workshops as windows_type_workshops ON windows_type_workshops.id = bookmarks.bookmarkable_id")
                    .where("windows_type_workshops.windows_type_id IN (?)", windows_type_ids)
                    .select("bookmarks.*, windows_type_workshops.*")
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
                    .joins("INNER JOIN workshops AS title_workshops ON title_workshops.id = bookmarks.bookmarkable_id")
                    .where("title_workshops.title LIKE ?", "%#{params[:title]}%")
                    .select("bookmarks.*, title_workshops.*") # ensure bookmark columns are present
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

    # Only apply search to Workshop bookmarks
    bookmarks = joins(
      "INNER JOIN workshops AS search_workshops ON search_workshops.id = bookmarks.bookmarkable_id"
    ).where(bookmarks: { bookmarkable_type: "Workshop" })

    # Whitelisted, quoted column names to use in search
    cols = %w[
    title full_name objective materials introduction demonstration opening_circle
    warm_up creation closing notes tips misc1 misc2
  ].map { |c| "search_workshops.#{connection.quote_column_name(c)}" }.join(", ")

    # Prepare query for BOOLEAN MODE (prefix matching)
    terms = query.to_s.strip.split.map { |term| "#{term}*" }.join(" ")

    # MATCH...AGAINST expression using the alias
    match_expr = Arel.sql("MATCH(#{cols}) AGAINST(? IN BOOLEAN MODE)")

    bookmarks
      .select(
        sanitize_sql_array(["bookmarks.*, search_workshops.*, #{match_expr} AS all_score", terms])
      )
      .where(match_expr, terms)
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
