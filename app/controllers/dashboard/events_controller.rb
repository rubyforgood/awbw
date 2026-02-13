module Dashboard
  class EventsController < ApplicationController
    def index
      authorize! :dashboard
      @events = authorized_scope(Event.includes(:bookmarks, :primary_asset)
                     .published
                     .order(:start_date), with: DashboardPolicy)
                     .decorate

      render "dashboard/events/index"
    end
  end
end
