class StorySharesController < ApplicationController
  include ExternallyRedirectable, AhoyTracking, StoryIdeaFormVariables

  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_story, only: [ :show ]

  FEATURED_SECTOR_LIMIT = 6
  SECTION_STORY_LIMIT = 5
  FEATURED_CAROUSEL_LIMIT = 10
  RELATED_STORY_LIMIT = 3
  POPULAR_STORY_LIMIT = 4
  BROWSE_CAROUSEL_LIMIT = 5
  BROWSE_GRID_LIMIT = 3
  # Any of these params means the visitor is browsing a filtered result set
  # rather than the curated landing page.
  BROWSE_PARAMS = %i[ sector_names_all category_names_all query additional_focus_areas year page ].freeze

  helper_method :browsing?, :single_hero?

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
    @related_stories = related_stories(portal_scope.where.not(id: @story.id))
    render layout: "story_shares"
  end

  # Signed-in "Share your story" — reuses the StoryIdea submission flow.
  def new
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
    scope.includes(:sectors, :organization, :primary_asset, sectorable_items: :sector, categorizable_items: :category)
  end

  def browsing?
    BROWSE_PARAMS.any? { |key| params[key].present? }
  end

  # Sector pages lead with one big hero; other browse pages lead with a carousel.
  def single_hero?
    params[:sector_names_all].present?
  end

  def load_home
    @home_sectors = Sector.story_share_home_sections.limit(FEATURED_SECTOR_LIMIT).to_a
    @stories_by_sector = @home_sectors.index_with do |sector|
      section_stories(portal_scope.with_primary_sector(sector))
    end
    @stories_by_audience = Category.story_share_audience_nav.select(&:story_share_home_section).index_with do |category|
      section_stories(portal_scope.with_primary_category(category))
    end
    @featured_stories = carousel_stories
    @recent_stories = popular_stories
  end

  # "What others are reading": the most-viewed visible stories by tracked page
  # views (Ahoy `view.story` events), backfilled with the most-bookmarked when
  # view data is thin so the section always fills. Order preserved.
  def popular_stories
    visible = portal_scope
    ids = Ahoy::Event.where(name: "view.story", resource_type: "Story", resource_id: visible.select(:id))
                     .group(:resource_id)
                     .order(Arel.sql("COUNT(*) DESC"))
                     .limit(POPULAR_STORY_LIMIT)
                     .pluck(:resource_id)
    if ids.size < POPULAR_STORY_LIMIT
      ids += visible.where.not(id: ids).reorder(bookmark_count_desc)
                    .limit(POPULAR_STORY_LIMIT - ids.size).pluck(:id)
    end
    preloaded(Story.where(id: ids)).in_order_of(:id, ids).decorate
  end

  # Publicly featured stories lead the section, then most recent, capped.
  def section_stories(scope)
    preloaded(scope).order(publicly_featured: :desc, created_at: :desc).limit(SECTION_STORY_LIMIT).decorate
  end

  # Hand-picked stories lead the hero carousel (by carousel order); fall back to
  # publicly featured then most recent so the carousel never empties.
  def carousel_stories
    stories = preloaded(portal_scope.story_share_carousel).limit(FEATURED_CAROUSEL_LIMIT)
    stories = preloaded(portal_scope.publicly_featured).order(created_at: :desc).limit(FEATURED_CAROUSEL_LIMIT) if stories.empty?
    stories = preloaded(portal_scope).order(created_at: :desc).limit(FEATURED_CAROUSEL_LIMIT) if stories.empty?
    stories.decorate
  end

  def load_browse
    per_page = params[:number_of_items_per_page].presence || 12
    filtered = portal_scope.search_by_params(params)
    filtered = filtered.with_sector(additional_focus_area_sectors) if params[:additional_focus_areas].present?
    @count_display = count_display(filtered.count)
    highlights = primary_tag_matches(filtered)
    lead_ids = highlights.reorder(publicly_featured: :desc, created_at: :desc).limit(single_hero? ? 1 : BROWSE_CAROUSEL_LIMIT).pluck(:id)
    grid_ids = highlights.where.not(id: lead_ids).reorder(created_at: :desc).limit(BROWSE_GRID_LIMIT).pluck(:id)
    @lead_stories = first_page? ? in_id_order(lead_ids) : []
    @grid_stories = first_page? ? in_id_order(grid_ids) : []
    @stories = preloaded(filtered.where.not(id: lead_ids + grid_ids)).order(created_at: :desc)
                                  .paginate(page: params[:page], per_page: per_page)
                                  .decorate
  end

  def in_id_order(ids)
    preloaded(Story.where(id: ids)).in_order_of(:id, ids).decorate
  end

  def first_page?
    params[:page].to_i <= 1
  end

  # The banner/carousel and 3-up cards feature only stories starring the browsed
  # tag as primary; stories carrying it as a secondary tag stay in the list below.
  def primary_tag_matches(stories)
    stories = stories.with_primary_sector(Sector.sector_names_all(params[:sector_names_all])) if params[:sector_names_all].present?
    stories = stories.with_primary_category(Category.category_names_all(params[:category_names_all])) if params[:category_names_all].present?
    stories = stories.with_primary_sector(additional_focus_area_sectors) if params[:additional_focus_areas].present?
    stories
  end

  # "Additional focus areas": published sectors beyond the featured nav sectors —
  # the catch-all page for the rest of the taxonomy.
  def additional_focus_area_sectors
    Sector.published.excluding_other.where.not(name: Sector.story_share_featured.select(:name))
  end

  # Related stories share a sector and/or a category, most-read first (then
  # newest), backfilled with the most-read remaining stories. Order preserved.
  def related_stories(others)
    sector_matches = @story.sector_ids.present? ?
      others.where(id: SectorableItem.where(sectorable_type: "Story", sector_id: @story.sector_ids).select(:sectorable_id)) :
      others.where(id: [])
    category_matches = @story.category_ids.present? ?
      others.where(id: CategorizableItem.where(categorizable_type: "Story", category_id: @story.category_ids).select(:categorizable_id)) :
      others.where(id: [])
    related = sector_matches.or(category_matches)

    ids = related.reorder(bookmark_count_desc).limit(RELATED_STORY_LIMIT).pluck(:id)
    if ids.size < RELATED_STORY_LIMIT
      ids += others.where.not(id: ids).reorder(bookmark_count_desc)
                   .limit(RELATED_STORY_LIMIT - ids.size).pluck(:id)
    end
    preloaded(Story.where(id: ids)).in_order_of(:id, ids).decorate
  end

  def bookmark_count_desc
    Arel.sql("(SELECT COUNT(*) FROM bookmarks WHERE bookmarks.bookmarkable_id = stories.id
               AND bookmarks.bookmarkable_type = 'Story') DESC, stories.created_at DESC")
  end
end
