module Dashboard
  class WorkshopsController < ApplicationController
    def index
      authorize! :dashboard
      ids = Rails.cache.fetch("featured_and_publicly_featured_workshop_ids", expires_in: 1.year) do
        Workshop.featured_or_publicly_featured.pluck(:id)
      end

      base_scope = Workshop.includes(:bookmarks, :windows_type, :primary_asset)
                        .where(id: ids)

      @workshops = authorized_scope(base_scope, with: DashboardPolicy).decorate
      @workshops = @workshops.sort { |x, y| Date.parse(y.date) <=> Date.parse(x.date) }

      render "dashboard/workshops/index"
    end
  end
end
