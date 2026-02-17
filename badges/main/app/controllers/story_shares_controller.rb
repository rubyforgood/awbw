class StorySharesController < ApplicationController
  include ExternallyRedirectable, AhoyTracking
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_story, only: [ :show ]

  def policy_class
    StorySharePolicy
  end

  def index
    authorize! Story
    per_page = params[:number_of_items_per_page].presence || 12
    base_scope = authorized_scope(Story.includes(:windows_type, :organization, :workshop, :created_by, :bookmarks, :primary_asset))
    filtered = base_scope.search_by_params(params)
                         .order(created_at: :desc)
    @stories = filtered.paginate(page: params[:page], per_page: per_page).decorate

    @count_display = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"

    popular_stories = @stories.sort_by { |s| s.bookmarks.size }.reverse.first(6)
    @popular_stories = Story.includes(:bookmarks, :primary_asset)
                            .where(id: popular_stories.map(&:id))
                            .decorate

    sector_names_all_params = params[:sector_names_all]
    @sector_names_all = sector_names_all_params.to_s.split("--") ||
      [ "Domestic Violence",
        "Social Justice",
        "Facilitator Spotlights" ]
    if sector_names_all_params.present? # render sector_index
      @stories_by_sector = { "Domestic Violence": Story.all.decorate }
      @featured_story = Story.first.decorate
      stories = Story.includes(:bookmarks, :primary_asset)
                     # .where(id: popular_stories.map(&:id))
                     .decorate
      @featured_stories = stories.first(3)
      @popular_stories = stories.drop(3)
    else
      @featured_story = Story.first.decorate

      @stories_by_sector = { "Domestic Violence": Story.all.decorate }
      # @sector_names_all.index_with do |sector|
      #   matching = @stories.select do |story|
      #     story.respond_to?(:sector_names_all) &&
      #       story.sector_names_all.include?(sector)
      #   end
      #
      #   remaining_needed = 5 - matching.size
      #   if remaining_needed > 0
      #     filler = @stories.reject { |story| matching.include?(story) }
      #                      .first(remaining_needed)
      #     matching + filler
      #   else
      #     matching.first(5)
      #   end
      # end
    end

    render layout: "story_shares"
  end

  def show
    @story = @story.decorate
    authorize! @story
    track_view(@story)

    # Fetch related stories for "What Others Are Reading" section
    base_scope = authorized_scope(Story.includes(:bookmarks, :primary_asset))
    @popular_stories =
      base_scope.where.not(id: @story.id)
                .order(
                  Arel.sql("(SELECT COUNT(*) FROM bookmarks WHERE
                                    bookmarks.bookmarkable_id = stories.id
                                  AND bookmarks.bookmarkable_type = 'Story') DESC, created_at DESC"))
                .limit(4)
                .decorate

    @featured_story = @popular_stories.first

    render layout: "story_shares"
  end

  private

  def set_story
    @story = Story.find(params[:id])
  end
end
