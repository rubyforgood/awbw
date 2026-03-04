class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :bookmarkable, polymorphic: true

  BOOKMARKABLE_MODELS = %w[CommunityNews Event Organization Person Report Resource Story StoryIdea
                           Tutorial Workshop WorkshopIdea WorkshopLog WorkshopVariation WorkshopVariationIdea].freeze

  DROPDOWN_MODELS = (BOOKMARKABLE_MODELS - %w[Report]).freeze

  def self.bookmarkable_type_options
    DROPDOWN_MODELS.map { |type| [ type.constantize.model_name.human, type ] }
  end

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
    bookmarks = user ? user.bookmarks : (is_a?(ActiveRecord::Relation) ? self : all)
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
    bookmarks = bookmarks.where(user_id: params[:user_id]) if params[:user_id].present?
    bookmarks = bookmarks.user_name(params[:user_name]) if params[:user_name].present?
    bookmarks = bookmarks.windows_type(params[:windows_type]) if params[:windows_type].present?

    bookmarks
  end

  # Use aliased table names (st_ prefix) to avoid conflicts with title scope's JOINs
  def self.sort_by_title
    bookmarks = self.joins(<<~SQL)
      LEFT JOIN community_news      AS st_cn  ON st_cn.id  = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'CommunityNews'
      LEFT JOIN events              AS st_ev  ON st_ev.id  = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Event'
      LEFT JOIN organizations       AS st_org ON st_org.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Organization'
      LEFT JOIN people              AS st_ppl ON st_ppl.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Person'
      LEFT JOIN resources           AS st_res ON st_res.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Resource'
      LEFT JOIN stories             AS st_st  ON st_st.id  = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Story'
      LEFT JOIN story_ideas         AS st_si  ON st_si.id  = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'StoryIdea'
      LEFT JOIN tutorials           AS st_tut ON st_tut.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Tutorial'
      LEFT JOIN workshops           AS st_ws  ON st_ws.id  = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Workshop'
      LEFT JOIN workshop_ideas      AS st_wi  ON st_wi.id  = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopIdea'
      LEFT JOIN workshop_logs       AS st_wl  ON st_wl.id  = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopLog'
      LEFT JOIN workshop_variations AS st_wv  ON st_wv.id  = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopVariation'
      LEFT JOIN workshop_variation_ideas AS st_wvi ON st_wvi.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopVariationIdea'
      LEFT JOIN reports             AS st_rpt ON st_rpt.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Report'
    SQL
    bookmarks.order(Arel.sql(<<~SQL.squish)
      LOWER(
        COALESCE(
          st_cn.title,
          st_ev.title,
          CONCAT(st_ppl.first_name, ' ', st_ppl.last_name),
          st_org.name,
          st_rpt.type,
          st_res.title,
          st_st.title,
          st_si.title,
          st_tut.title,
          st_ws.title,
          st_wi.title,
          DATE_FORMAT(st_wl.date, '%Y-%m-%d'),
          st_wv.name,
          st_wvi.name
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
      LEFT JOIN organizations  ON organizations.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Organization'
      LEFT JOIN people         ON people.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Person'
      LEFT JOIN resources      ON resources.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Resource'
      LEFT JOIN stories        ON stories.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Story'
      LEFT JOIN story_ideas    ON story_ideas.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'StoryIdea'
      LEFT JOIN tutorials      ON tutorials.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Tutorial'
      LEFT JOIN workshops      ON workshops.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Workshop'
      LEFT JOIN workshop_ideas ON workshop_ideas.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopIdea'
      LEFT JOIN workshop_logs ON workshop_logs.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopLog'
      LEFT JOIN workshop_variations ON workshop_variations.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopVariation'
      LEFT JOIN workshop_variation_ideas ON workshop_variation_ideas.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'WorkshopVariationIdea'
      LEFT JOIN reports ON reports.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Report'
    SQL

    bookmarks.where(
      "community_news.title LIKE :title OR events.title LIKE :title OR people.first_name LIKE :title OR
       people.last_name LIKE :title OR organizations.name LIKE :title OR resources.title LIKE :title OR
       reports.type LIKE :title OR
       stories.title LIKE :title OR workshops.title LIKE :title OR workshop_ideas.title LIKE :title OR
       story_ideas.body LIKE :title OR -- searching body for story ideas (title exists but isn't used in UI)
       tutorials.title LIKE :title OR
       DATE_FORMAT(workshop_logs.date, '%Y-%m-%d') LIKE :title OR -- no title on workshop_logs
       workshop_variations.name LIKE :title OR
       workshop_variation_ideas.name LIKE :title",
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

    # Use aliased table names to avoid conflicts with title scope's LEFT JOINs
    joins(<<~SQL)
      LEFT JOIN resources AS wt_resources
        ON wt_resources.id = bookmarks.bookmarkable_id
       AND bookmarks.bookmarkable_type = 'Resource'
       AND wt_resources.windows_type_id IS NOT NULL
      LEFT JOIN windows_types AS wt_res_types
        ON wt_res_types.id = wt_resources.windows_type_id
      LEFT JOIN workshops AS wt_workshops
        ON wt_workshops.id = bookmarks.bookmarkable_id
       AND bookmarks.bookmarkable_type = 'Workshop'
       AND wt_workshops.windows_type_id IS NOT NULL
      LEFT JOIN windows_types AS wt_ws_types
        ON wt_ws_types.id = wt_workshops.windows_type_id
    SQL
    .where("wt_res_types.name LIKE :pattern OR wt_ws_types.name LIKE :pattern", pattern: pattern)
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
