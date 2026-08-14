module Api
  module V1
    # Admin-only JSON API for grants. Authentication stays on (inherited from
    # ApplicationController) and GrantPolicy gates every action to admins.
    class GrantsController < Api::BaseController
      # Cap page size so a caller can't request an unbounded payload.
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      # GET /api/v1/grants
      def index
        authorize! Grant, to: :index?
        @grants = authorized_scope(Grant.all)
          .includes(:funder, :sectors, :scholarships, categories: :category_type)
          .by_deadline
          .paginate(page: params[:page], per_page: per_page)
      end

      # GET /api/v1/grants/:id
      def show
        @grant = authorized_scope(Grant.all).find(params[:id])
        authorize! @grant
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
