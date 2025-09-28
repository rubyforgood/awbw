class DashboardController < ApplicationController
  skip_before_action :authenticate_user!, only: :help

  layout "help", only: :help
  layout "tailwind", only: :index

  def index
    @user = current_user.decorate
    @workshops = current_user.curriculum(Workshop)
      .featured.includes(:sectors).decorate
    @workshops = @workshops.sort { |x, y| Date.parse(y.date) <=> Date.parse(x.date) }

    @resources = Resource.published.featured.where(kind: [nil, "Resource",
      "Template", "Handout", "Scholarship", "Toolkit", "Form"])
      .decorate

    @stories = Resource.story.featured.decorate
    @themes = Resource.theme.featured.decorate
    @sector_impacts = Resource.sector_impact.featured.decorate
    @recent_activity = current_user.recent_activity
  end

  def recent_activity
    @recent_activity = current_user.recent_activity(20)
  end
end
