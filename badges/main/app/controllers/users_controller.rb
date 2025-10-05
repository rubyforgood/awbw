class UsersController < ApplicationController

  def index
    if current_user.super_user?
      @users = User.paginate(page: params[:page], per_page: 25)
    else
      redirect_to authenticated_root_path
    end
  end

  def new
    @user = User.new
    @user.project_users.build
    @projects = current_user.projects
  end

  def create
    @user = User.new(user_params)
    set_password
    if @user.save
      @user.notifications.create(notification_type: 0)
      flash[:notice] = 'User has been created.'
      redirect_to users_path
    else
      render :new
    end
  end

  def show
    @user = User.find(params[:id]).decorate
  end

  def edit
    @user = User.find(params[:id])
  end

  def change_password
    @user = current_user
  end

  def update_password
    @user = current_user

    if @user.update_with_password(pass_params)
      bypass_sign_in(@user)
      flash[:notice] = 'Your Password was updated.'
      redirect_to authenticated_root_path
    else
      flash[:alert] = "#{@user.errors.full_messages.join(", ")}"
      render "change_password"
    end
  end

  def update
    @user = User.find(params[:id])
    set_password unless password_param.nil?

    if @user.update(user_params)
      # @user.notifications.create(notification_type: 1)
      flash[:notice] = 'User updated.'
      redirect_to users_path
    else
      flash[:alert] = 'Unable to update user.'
      render :edit
    end
  end

  private

  def set_password
    @user.password = password_param unless password_param.empty?
  end

  def user_params
    params.require(:user).permit(
      :email, :first_name, :last_name,
      :phone, :phone2, :phone3, :best_time_to_call,
      :birthday, :address, :city, :state, :zip, :address2,
      :city2, :state2, :zip2, :primary_address, :notes, :avatar, :super_user,
      project_users_attributes: [:project_id, :position, :_destroy, :id]
    )
  end

  def password_param
    params[:user][:password]
  end

  def pass_params
    # NOTE: Using `strong_parameters` gem
    params.permit(:current_password, :password, :password_confirmation)
  end
end
