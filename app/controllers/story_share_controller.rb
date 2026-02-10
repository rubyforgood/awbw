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
        # @stories.select { |story| story.sectors.any? { |s| s.name == focus } }
        @stories.first(5)
      end
    @popular_stories = @stories.sort_by { |s| s.bookmarks.size }.reverse.first(6)

    render layout: "story_share"
  end

  def show
    @story = @story.decorate
    authorize! @story
    track_view(@story)

    if @story.external_url.present? && !params[:no_redirect].present?
      redirect_to_external @story.link_target
      nil
    end
  end

  private

  def set_story
    @story = Story.find(params[:id])
  end
end
