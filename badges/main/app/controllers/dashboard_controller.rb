class DashboardController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    authorize! :dashboard
    render :index
  end
end
