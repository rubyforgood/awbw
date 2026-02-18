module Dashboard
  class ResourcesController < ApplicationController
    def index
      authorize! :dashboard
      @resources = authorized_scope(Resource.includes(primary_asset: { file_attachment: :blob }, downloadable_asset: { file_attachment: :blob }, gallery_assets: { file_attachment: :blob })
                           .published
                           .order(position: :asc, created_at: :desc), with: DashboardPolicy)
                           .decorate

      render "dashboard/resources/index"
    end
  end
end
