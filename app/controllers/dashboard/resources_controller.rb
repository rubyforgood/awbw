module Dashboard
  class ResourcesController < ApplicationController
    def index
      authorize! :dashboard
      @resources = authorized_scope(Resource.includes(:bookmarks, :primary_asset, :downloadable_asset)
                           .published
                           .order(position: :asc, created_at: :desc), with: DashboardPolicy)
                           .decorate

      render "dashboard/resources/index"
    end
  end
end
