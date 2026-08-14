module Api
  module V1
    class StoriesController < Api::BaseController
      # Cap page size so a caller can't request an unbounded payload.
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      # GET /api/v1/stories
      # Publicly visible stories (published + publicly_visible). Each record
      # exposes its `featured` and `publicly_featured` flags. Pass
      # `?publicly_featured=true` to return only the public-featured set.
      def index
        authorize! Story, to: :index?
        # `authorized_scope` applies StoryPolicy (anonymous callers collapse to
        # `publicly_visible`); starting from `Story.publicly_visible` guarantees
        # the public floor for any caller.
        scope = authorized_scope(Story.publicly_visible)
        scope = scope.publicly_featured if publicly_featured_filter?

        @stories = scope
          .includes(:windows_type, :organization, :author, :primary_asset, :sectors, created_by: :person)
          .order(created_at: :desc)
          .paginate(page: params[:page], per_page: per_page)
      end

      # GET /api/v1/stories/:id
      def show
        @story = Story.publicly_visible.find(params[:id])
        authorize! @story
      end

      private

      def publicly_featured_filter?
        ActiveModel::Type::Boolean.new.cast(params[:publicly_featured])
      end

      def per_page
        requested = params[:per_page].to_i
        return DEFAULT_PER_PAGE unless requested.positive?
        [ requested, MAX_PER_PAGE ].min
      end
    end
  end
end
