module Home
  class EventsController < ApplicationController
    def index
      authorize! :home
      @events = authorized_scope(Event.includes(:bookmarks, :primary_asset)
                     .published
                     .order(:start_date), with: HomePolicy)
                     .decorate

      render "home/events/index"
    end
  end
end
