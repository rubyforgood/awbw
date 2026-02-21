module Home
  class ResourcesController < ApplicationController
    def index
      authorize! :home
      @resources = authorized_scope(Resource.includes(primary_asset: { file_attachment: :blob }, downloadable_asset: { file_attachment: :blob }, gallery_assets: { file_attachment: :blob })
                           .published
                           .order(position: :asc, created_at: :desc), with: HomePolicy)
                           .decorate

      render "home/resources/index"
    end
  end
end
