class Admins::BaseController < ActionController::Base
  before_action :authenticate_admin!
  def show
    redirect_to rails_admin_path
  end
end