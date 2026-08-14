module Api
  module V1
    class StoriesController < Api::BaseController
      # Cap page size so a caller can't request an unbounded payload.
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      # GET /api/v1/stories
      # Publicly featured stories only (published + publicly_visible +
      # publicly_featured).
      def index
        authorize! Story, to: :index?
        # `authorized_scope` layers StoryPolicy (anonymous callers collapse to
        # `publicly_visible`) over the `publicly_featured` scope, which already
        # includes the public floor.
        @stories = authorized_scope(Story.publicly_featured)
          .includes(:windows_type, :organization, :author, :primary_asset, :sectors,
                    { categories: :category_type }, created_by: :person)
          .order(created_at: :desc)
          .paginate(page: params[:page], per_page: per_page)
      end

      # GET /api/v1/stories/:id
      def show
        @story = Story.publicly_featured.find(params[:id])
        authorize! @story
      end

      private

      def per_page
        requested = params[:per_page].to_i
        return DEFAULT_PER_PAGE unless requested.positive?
        [ requested, MAX_PER_PAGE ].min
      end
    end
  end
end
