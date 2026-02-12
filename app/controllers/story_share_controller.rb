class StoryShareController < ApplicationController
  include ExternallyRedirectable, AhoyTracking
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_story, only: [ :show ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 12
    base_scope = authorized_scope(Story.includes(:windows_type, :organization, :workshop, :created_by, :bookmarks, :primary_asset))
    filtered = base_scope.search_by_params(params)
                         .order(created_at: :desc)
    @stories = filtered.paginate(page: params[:page], per_page: per_page).decorate

    @count_display = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"

    @featured_story = Story.first
    sector_names = [
      "Domestic Violence",
      "Social Justice",
      "Facilitator Spotlights"
    ]

    @stories_by_focus =
      sector_names.index_with do |focus|
        matching = @stories.select do |story|
          story.respond_to?(:sector_names_all) &&
            story.sector_names_all.include?(focus)
        end

        remaining_needed = 5 - matching.size
        if remaining_needed > 0
          filler = @stories.reject { |story| matching.include?(story) }
                           .first(remaining_needed)
          matching + filler
        else
          matching.first(5)
        end
      end
    @popular_stories = @stories.sort_by { |s| s.bookmarks.size }.reverse.first(6)

    render layout: "share_portal"
  end

  def show
    @story = @story.decorate
    authorize! @story
    track_view(@story)

    # Fetch related stories for "What Others Are Reading" section
    base_scope = authorized_scope(Story.includes(:bookmarks, :primary_asset))
    @popular_stories = base_scope.where.not(id: @story.id)
                                 .order(Arel.sql("(SELECT COUNT(*) FROM bookmarks WHERE bookmarks.resource_id = stories.id AND bookmarks.resource_type = 'Story') DESC, created_at DESC"))
                                 .limit(4)
                                 .decorate

    render layout: "share_portal"
  end

  private

  def set_story
    @story = Story.find(params[:id])
  end
end
