class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :bookmarkable, polymorphic: true

  BOOKMARKABLE_MODELS = [ "CommunityNews", "Event", "Facilitator", "Project", "Resource", "Story", "StoryIdea",
                        "Workshop", "WorkshopIdea", "WorkshopLog", "WorkshopVariation" ]

  scope :for_workshops, -> { where(bookmarkable_type: "Workshop") }
  scope :bookmarkable_type, ->(bookmarkable_type) { bookmarkable_type.present? ? where(bookmarkable_type: bookmarkable_type) : all }
  scope :bookmarkable_attributes, ->(bookmarkable_type, bookmarkable_id) {
    bookmarkable_type.present? && bookmarkable_id.present? ? where(bookmarkable_type: bookmarkable_type,
                                                                   bookmarkable_id: bookmarkable_id) : all }

  scope :sort_by_newest, -> { order(created_at: :desc) }
  scope :sort_by_popularity, -> {
    select("bookmarks.*, COUNT(all_b.id) as popularity")
      .joins("LEFT JOIN bookmarks all_b ON all_b.bookmarkable_id = bookmarks.bookmarkable_id AND
        all_b.bookmarkable_type = bookmarks.bookmarkable_type")
      .group("bookmarks.id")
      .order("popularity DESC") }


  def self.search(params, user: nil)
    bookmarks = user ? user.bookmarks : self.all
    bookmarks = bookmarks.filter_by_params(params)
    bookmarks = bookmarks.sorted(params[:sort])
    bookmarks
  end

  def self.sorted(sort_by = nil) # sort and sort_by are namespaced
    sort_by ||= "newest"
    case sort_by
    when "newest"        then self.sort_by_newest
    when "title"         then self.sort_by_title
    when "popularity"    then self.sort_by_popularity
    else self.sort_by_newest
    end
  end

  def self.filter_by_params(params = {})
    bookmarks = self.all

    bookmarks = bookmarks.bookmarkable_type(params[:bookmarkable_type])
    bookmarks = bookmarks.bookmarkable_attributes(params[:bookmarkable_type],
                                                  params[:bookmarkable_id])
    bookmarks = bookmarks.title(params[:title]) if params[:title].present?
    bookmarks = bookmarks.user_name(params[:user_name]) if params[:user_name].present?
    bookmarks = bookmarks.windows_type(params[:windows_type]) if params[:windows_type].present?

    bookmarks
  end

  def self.sort_by_title
    bookmarks = self.joins(<<~SQL)
      LEFT JOIN community_news      ON community_news.id      = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'CommunityNews'
      LEFT JOIN events              ON events.id              = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Event'
      LEFT JOIN facilitators        ON facilitators.id        = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Facilitator'
      LEFT JOIN projects            ON projects.id            = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Project'
      LEFT JOIN resources           ON resources.id           = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Resource'
      LEFT JOIN stories             ON stories.id             = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Story'
      LEFT JOIN story_ideas         ON story_ideas.id         = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'StoryIdea'
      LEFT JOIN workshops           ON workshops.id           = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Workshop'
      LEFT JOIN workshop_ideas      ON workshop_ideas.id      = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopIdea'
      LEFT JOIN workshop_logs       ON workshop_logs.id       = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopLog'
      LEFT JOIN workshop_variations ON workshop_variations.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopVariation'
    SQL
    bookmarks.order(Arel.sql(<<~SQL.squish)
      LOWER(
        COALESCE(
          community_news.title,
          events.title,
          CONCAT(facilitators.first_name, ' ', facilitators.last_name),
          projects.name,
          resources.title,
          stories.title,
          story_ideas.title,
          workshops.title,
          workshop_ideas.title,
          DATE_FORMAT(workshop_logs.date, '%Y-%m-%d'),
          workshop_variations.name
        )
      ) ASC,
      bookmarks.created_at DESC
    SQL
    )
  end

  def self.title(title)
    return all unless title.present?

    bookmarks = self.all
    bookmarks = bookmarks.joins(<<~SQL)
      LEFT JOIN community_news ON community_news.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'CommunityNews'
      LEFT JOIN events         ON events.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Event'
      LEFT JOIN facilitators   ON facilitators.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Facilitator'
      LEFT JOIN projects       ON projects.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Project'
      LEFT JOIN resources      ON resources.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Resource'
      LEFT JOIN stories        ON stories.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Story'
      LEFT JOIN story_ideas    ON story_ideas.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'StoryIdea'
      LEFT JOIN workshops      ON workshops.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Workshop'
      LEFT JOIN workshop_ideas ON workshop_ideas.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopIdea'
      LEFT JOIN workshop_logs ON workshop_logs.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopLog'
      LEFT JOIN workshop_variations ON workshop_variations.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopVariation'
    SQL

    bookmarks.where(
      "community_news.title LIKE :title OR events.title LIKE :title OR facilitators.first_name LIKE :title OR
       facilitators.last_name LIKE :title OR projects.name LIKE :title OR resources.title LIKE :title OR
       stories.title LIKE :title OR workshops.title LIKE :title OR workshop_ideas.title LIKE :title OR
       story_ideas.body LIKE :title OR -- searching body for story ideas (title exists but isn't used in UI)
       DATE_FORMAT(workshop_logs.date, '%Y-%m-%d') LIKE :title OR -- no title on workshop_logs
       workshop_variations.name LIKE :title -- searching name for workshop variations (title doesn't exist)
                            ",
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

    user_name_sanitized = user_name.strip.gsub(/\s+/, "")

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

  def primary_asset
    bookmarkable.respond_to?(:primary_asset) ? bookmarkable.primary_asset : nil
  end
end
