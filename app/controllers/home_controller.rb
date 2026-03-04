class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    authorize! :home

    respond_to do |format|
      format.html { render :index }
    end
  end
end
