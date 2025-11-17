class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :bookmarkable, polymorphic: true

  scope :for_workshops, -> { where(bookmarkable_type: 'Workshop') }
  scope :bookmarkable_type, -> (bookmarkable_type) { bookmarkable_type.present? ? where(bookmarkable_type: bookmarkable_type) : all }
  scope :bookmarkable_attributes, -> (bookmarkable_type, bookmarkable_id) {
    bookmarkable_type.present? && bookmarkable_id.present? ? where(bookmarkable_type: bookmarkable_type,
                                                                   bookmarkable_id: bookmarkable_id) : all }

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

    bookmarks = bookmarks.bookmarkable_type(params[:bookmarkable_type])
    bookmarks = bookmarks.bookmarkable_attributes(params[:bookmarkable_type],
                                                  params[:bookmarkable_id])
    bookmarks = bookmarks.title(params[:title])
    bookmarks = bookmarks.user_name(params[:user_name])
    bookmarks = bookmarks.windows_type(params[:windows_type])

    bookmarks
  end

  def self.title(title)
    return all unless title.present?

    bookmarks = self.all
    bookmarks = bookmarks.joins(<<~SQL)
      LEFT JOIN workshops ON workshops.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Workshop'
--      LEFT JOIN stories   ON stories.id   = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Story'
      LEFT JOIN resources ON resources.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Resource'
      LEFT JOIN events    ON events.id    = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Event'
    SQL

    bookmarks.where(
      "workshops.title LIKE :title OR events.title LIKE :title OR resources.title LIKE :title", # OR stories.title LIKE :title
      title: "%#{title}%"
    )
  end

  def self.windows_type(windows_type)
    return all unless windows_type.present?
    case windows_type.downcase
    when /adult/
      normalized = "ADULT WORKSHOP"
    when /child/
      normalized = "CHILDREN WORKSHOP"
    when /combined/
      normalized = "COMBINED"
    else
      normalized = windows_type
    end

    pattern = "%#{normalized}%"

    # Resources with a windows_type
    resources = joins(
      <<~SQL
      INNER JOIN resources
        ON resources.id = bookmarks.bookmarkable_id
       AND bookmarks.bookmarkable_type = 'Resource'
      INNER JOIN windows_types
        ON windows_types.id = resources.windows_type_id
        AND resources.windows_type_id IS NOT NULL
    SQL
    ).where("windows_types.name LIKE ?", pattern)

    # Workshops (optional windows_type)
    workshops = joins(
      <<~SQL
      LEFT JOIN workshops
        ON workshops.id = bookmarks.bookmarkable_id
       AND bookmarks.bookmarkable_type = 'Workshop'
      LEFT JOIN windows_types
        ON windows_types.id = workshops.windows_type_id
        AND workshops.windows_type_id IS NOT NULL
    SQL
    ).where("windows_types.name LIKE ?", pattern)

    # Combine results in a single relation
    self.where(id: resources.select(:id)).or(self.where(id: workshops.select(:id)))
  end

  def self.user_name(user_name)
    return all unless user_name.present?

    user_name_sanitized = user_name.strip.gsub(/\s+/, '')

    bookmarks = self.left_outer_joins(:user)

    # Join workshops only if we might filter by them
    bookmarks = bookmarks.joins(
      "LEFT JOIN workshops ON workshops.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Workshop'"
    )

    bookmarks.where(
      <<~SQL.squish,
        LOWER(REPLACE(users.first_name, ' ', '')) LIKE :name
        OR LOWER(REPLACE(users.last_name, ' ', '')) LIKE :name
        OR LOWER(REPLACE(CONCAT(users.first_name, users.last_name), ' ', '')) LIKE :name
        OR LOWER(REPLACE(CONCAT(users.last_name, users.first_name), ' ', '')) LIKE :name
        OR (
          bookmarks.bookmarkable_type = 'Workshop'
          AND LOWER(REPLACE(workshops.full_name, ' ', '')) LIKE :name
        )
      SQL
      name: "%#{user_name_sanitized}%"
    )
  end

  def bookmarkable_image_url(fallback: 'missing.png')
    if bookmarkable.respond_to?(:images) && bookmarkable.images.first&.file&.attached?
      Rails.application.routes.url_helpers.rails_blob_path(bookmarkable.images.first.file, only_path: true)
    elsif bookmarkable_type == "Workshop"
      ActionController::Base.helpers.asset_path("workshop_default.jpg")
    else
      ActionController::Base.helpers.asset_path(fallback)
    end
  end
end
