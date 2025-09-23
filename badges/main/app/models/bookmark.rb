class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :bookmarkable, polymorphic: true
  has_many :bookmark_annotations, dependent: :destroy

  scope :for_workshops, -> { where(bookmarkable_type: 'Workshop') }

  def self.filter_by_windows_type_ids(windows_type_ids)
    bookmarks = self.all
    if windows_type_ids
      bookmarks = bookmarks
                    .where(bookmarkable_type: "Workshop")
                    .joins("INNER JOIN workshops as windows_type_workshops ON windows_type_workshops.id = bookmarks.bookmarkable_id")
                    .where("windows_type_workshops.windows_type_id IN (?)", windows_type_ids)
                    .select("bookmarks.*, windows_type_workshops.*")
                    .order("windows_type_workshops.windows_type_id DESC, windows_type_workshops.title ASC")
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

    terms = query.strip.split.map { |t| "#{t}*" }.join(" ")

    joins("INNER JOIN workshops AS search_workshops ON search_workshops.id = bookmarks.bookmarkable_id")
      .for_workshops
      .select("bookmarks.*")
      .where(
        "MATCH(search_workshops.title, search_workshops.full_name, search_workshops.objective, search_workshops.materials,
             search_workshops.introduction, search_workshops.demonstration, search_workshops.opening_circle, search_workshops.warm_up,
             search_workshops.creation, search_workshops.closing, search_workshops.notes, search_workshops.tips, search_workshops.misc1,
             search_workshops.misc2) AGAINST(? IN BOOLEAN MODE)", terms
      )
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

    bookmarks
  end
end
