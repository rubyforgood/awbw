class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    authorize! :home
    render :index
  end
end
