class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :bookmarkable, polymorphic: true
  has_many :bookmark_annotations, dependent: :destroy

  scope :for_workshops, -> { where(bookmarkable_type: 'Workshop') }

  def self.search(params, user: nil)
    bookmarks = user ? user.bookmarks : self.all
    bookmarks = bookmarks.filter_by_params(params)

    sort = params[:sort].presence || "title"

    case sort
    when "title"
      bookmarks = bookmarks
                    .joins(<<~SQL)
                    LEFT JOIN workshops ON bookmarks.bookmarkable_type = 'Workshop' AND workshops.id = bookmarks.bookmarkable_id
--                  LEFT JOIN stories   ON bookmarks.bookmarkable_type = 'Story' AND stories.id = bookmarks.bookmarkable_id
                    LEFT JOIN resources ON bookmarks.bookmarkable_type = 'Resource' AND resources.id = bookmarks.bookmarkable_id
                    LEFT JOIN events    ON bookmarks.bookmarkable_type = 'Event' AND events.id = bookmarks.bookmarkable_id
                  SQL
                    .order(Arel.sql("COALESCE(workshops.title, resources.title, events.title) ASC")) # stories.title,
    when "led"
      bookmarks = bookmarks.where(bookmarkable_type: "Workshop")
                           .joins("INNER JOIN workshops ON bookmarks.bookmarkable_id = workshops.id")
                           .order("workshops.led_count DESC")
    when "bookmark_count"
      counts = bookmarks.group(:bookmarkable_type, :bookmarkable_id)
                       .select(:bookmarkable_type, :bookmarkable_id, "COUNT(*) AS total_bookmarks")
      bookmarks = bookmarks
                    .joins("LEFT JOIN (#{counts.to_sql}) AS counts
                        ON counts.bookmarkable_type = bookmarks.bookmarkable_type
                        AND counts.bookmarkable_id = bookmarks.bookmarkable_id")
                    .order(Arel.sql("COALESCE(counts.total_bookmarks,0) DESC"))
    when "created"
      bookmarks = bookmarks.order(created_at: :desc)
    end

    bookmarks
  end

  def self.filter_by_params(params={})
    bookmarks = self.all
    # filter by
    if params[:bookmarkable_id].present? && params[:bookmarkable_type].present?
      bookmarks = bookmarks.where(bookmarkable_id: params[:bookmarkable_id],
                                  bookmarkable_type: params[:bookmarkable_type])
    end
    if params[:bookmarkable_type].present?
      bookmarks = bookmarks.where(bookmarkable_type: params[:bookmarkable_type])
    end
    if params[:title].present?
      title = "%#{params[:title]}%"
      bookmarks = bookmarks.joins(<<~SQL)
        LEFT JOIN workshops ON workshops.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Workshop'
--      LEFT JOIN stories   ON stories.id   = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Story'
        LEFT JOIN resources ON resources.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Resource'
        LEFT JOIN events    ON events.id    = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Event'
      SQL

      bookmarks = bookmarks.where(
        "workshops.title LIKE :title OR events.title LIKE :title OR resources.title LIKE :title", # OR stories.title LIKE :title
        title: title
      )
    end
    if params[:user_name].present?
      user_name_sanitized = params[:user_name].strip.gsub(/\s+/, '')
      bookmarks = bookmarks.left_outer_joins(:user)
                           .where("LOWER(REPLACE(workshops.full_name, ' ', '')) LIKE :name
                                  OR LOWER(REPLACE(CONCAT(users.first_name, users.last_name), ' ', '')) LIKE :name
                                  OR LOWER(REPLACE(CONCAT(users.last_name, users.first_name), ' ', '')) LIKE :name
                                  OR LOWER(REPLACE(users.first_name, ' ', '')) LIKE :name
                                  OR LOWER(REPLACE(users.last_name, ' ', '')) LIKE :name",
                                  name: "%#{user_name_sanitized}%")
    end

    bookmarks
  end
end
