class ImpersonateUsersController < ApplicationController

  before_action :check_current_user_is_super_user

  def index
    if params[:q]
      @users = User.where('first_name like ? or last_name like ?',
                          "#{params[:q]}%", "#{params[:q]}%").
                 paginate(page: params[:page], per_page: 10)
    else
      @users = User.all.paginate(page: params[:page], per_page: 10)
    end
  end

  def impersonate
    session[:i_user] = params[:i_user]
    redirect_to :root
  end

  def back
    session[:i_user] = nil
    redirect_to :root
  end

  private

  def check_current_user_is_super_user
    unless devise_current_user.super_user?
      redirect_to(authenticated_root_path, status: 401)
    end
  end
end
