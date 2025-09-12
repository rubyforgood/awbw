class UsersController < ApplicationController

  def new
    if current_user.liaison?
      @user = User.new
      @user.project_users.build
      @projects = current_user.projects
    else
      flash[:alert] = 'You must be a liaison to add a new user.'
      redirect_to root_path
    end
  end

  def create
    @user = User.new(user_params)
    set_password
    if @user.save
      @user.notifications.create(notification_type: 0)
      flash[:alert] = 'User has been created.'
      redirect_to user_path(@user)
    else
      render :new
    end
  end

  def show
    @user = User.find(params[:id]).decorate
  end

  def edit
    @user = User.find(params[:id])
    if can_access_page?
      @project_users = @user.project_users
      render :edit
    else
      flash[:alert] = 'You must be a liaison to edit user information.'
      redirect_to root_path
    end
  end

  def change_password
    @user = current_user
  end

  def update_password
    @user = current_user

    if @user.update_with_password(pass_params)
      sign_in(@user, :bypass => true)
      flash[:alert] = 'Your Password was updated.'
      redirect_to root_path
    else
      flash[:error] = "#{@user.errors.full_messages.join(", ")}"
      render "change_password"
    end
  end

  def update
    @user = User.find(params[:id])
    if can_access_page?
      set_password unless password_param.empty?

      if @user.update(user_params)
        @user.notifications.create(notification_type: 1)
        flash[:alert] = 'User updated.'
        sign_in(@user, :bypass => true)
        redirect_to user_path(@user)
      else
        flash[:alert] = 'Unable to update user.'
        render :edit
      end
    else
      flash[:alert] = 'You are not authorized to update this user.'
      redirect_to root_path
    end
  end

  private

  def set_password
    @user.password = password_param unless password_param.empty?
  end

  def can_access_page?
    @user == current_user || current_user.liaison_in_projects?(@user.projects)
  end

  # def user_params
  #   params.require(:user).permit(
  #     :email, :first_name, :last_name,
  #     :phone, :phone2, :phone3, :best_time_to_call,
  #     :birthday, :address, :city, :state, :zip, :address2,
  #     :city2, :state2, :zip2, :primary_address, :notes, :avatar,
  #     project_users_attributes: [:project_id, :position, :_destroy, :id]
  #   )
  # end

  # def password_param
  #   params[:user][:password]
  # end

  def pass_params
    # NOTE: Using `strong_parameters` gem
    params.permit(:current_password, :password, :password_confirmation)
  end
end
