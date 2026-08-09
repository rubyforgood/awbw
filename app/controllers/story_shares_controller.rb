class StorySharesController < ApplicationController
  include ExternallyRedirectable, AhoyTracking, StoryIdeaFormVariables

  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_story, only: [ :show ]

  FEATURED_SECTOR_LIMIT = 6
  SECTION_STORY_LIMIT = 5
  FEATURED_CAROUSEL_LIMIT = 10
  RELATED_STORY_LIMIT = 3
  POPULAR_STORY_LIMIT = 4
  # Any of these params means the visitor is browsing a filtered result set
  # rather than the curated landing page.
  BROWSE_PARAMS = %i[ sector_names_all category_names_all query facilitator_spotlights year page ].freeze

  helper_method :browsing?

  def index
    authorize! Story, with: StorySharePolicy
    browsing? ? load_browse : load_home
    render layout: "story_shares"
  end

  def show
    @story = @story.decorate
    authorize! @story, with: StorySharePolicy
    return redirect_to_external(@story.link_target) if @story.external_url.present? && params[:no_redirect].blank?

    track_view(@story)
    others = portal_scope.where.not(id: @story.id)
    @related_stories = related_stories(others)
    @popular_stories = preloaded(others).order(bookmark_count_desc).limit(POPULAR_STORY_LIMIT).decorate
    render layout: "story_shares"
  end

  # Signed-in "Share your story" — reuses the StoryIdea submission flow.
  def share
    @story_idea = StoryIdea.new
    authorize! @story_idea, to: :create?
    set_story_idea_form_variables
    render layout: "story_shares"
  end

  private

  def set_story
    @story = Story.find(params[:id])
  end

  def portal_scope
    authorized_scope(Story.all, with: StorySharePolicy)
  end

  def preloaded(scope)
    scope.includes(:sectors, :organization, :primary_asset)
  end

  def browsing?
    BROWSE_PARAMS.any? { |key| params[key].present? }
  end

  def load_home
    @featured_sectors = Sector.story_share_featured.limit(FEATURED_SECTOR_LIMIT).to_a
    @stories_by_sector = @featured_sectors.index_with do |sector|
      section_stories(portal_scope.sector_names_all(sector.name))
    end
    @spotlight_stories = section_stories(portal_scope.facilitator_spotlights(true))
    @featured_stories = carousel_stories
    @recent_stories = preloaded(portal_scope).order(bookmark_count_desc).limit(POPULAR_STORY_LIMIT).decorate
  end

  # Publicly featured stories lead the section, then most recent, capped.
  def section_stories(scope)
    preloaded(scope).order(publicly_featured: :desc, created_at: :desc).limit(SECTION_STORY_LIMIT).decorate
  end

  # Prefer publicly featured stories for the hero carousel; fall back to recent.
  def carousel_stories
    featured = preloaded(portal_scope.publicly_featured).order(created_at: :desc).limit(FEATURED_CAROUSEL_LIMIT)
    featured = preloaded(portal_scope).order(created_at: :desc).limit(FEATURED_CAROUSEL_LIMIT) if featured.empty?
    featured.decorate
  end

  def load_browse
    per_page = params[:number_of_items_per_page].presence || 12
    filtered = portal_scope.search_by_params(params)
    @count_display = filtered.count
    @stories = preloaded(filtered).order(created_at: :desc)
                                  .paginate(page: params[:page], per_page: per_page)
                                  .decorate
  end

  # Related stories share a sector, backfilled with recent ones, order preserved.
  def related_stories(others)
    ids = others.joins(:sectors).where(sectors: { id: @story.sector_ids }).distinct
                .order(created_at: :desc).limit(RELATED_STORY_LIMIT).pluck(:id)
    if ids.size < RELATED_STORY_LIMIT
      ids += others.where.not(id: ids).order(created_at: :desc)
                   .limit(RELATED_STORY_LIMIT - ids.size).pluck(:id)
    end
    preloaded(Story.where(id: ids)).in_order_of(:id, ids).decorate
  end

  def bookmark_count_desc
    Arel.sql("(SELECT COUNT(*) FROM bookmarks WHERE bookmarks.bookmarkable_id = stories.id
               AND bookmarks.bookmarkable_type = 'Story') DESC, stories.created_at DESC")
  end
end
