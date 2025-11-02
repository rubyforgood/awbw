class UsersController < ApplicationController
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index
     return redirect_to authenticated_root_path unless current_user.super_user?

    per_page = params[:number_of_items_per_page].presence || 25
    users = User.search_by_params(params).order(:first_name, :last_name)
    @users = users.paginate(page: params[:page], per_page: per_page)
    @users_count = users.size
  end

  def new
    @user = User.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def show
    @user = User.find(params[:id]).decorate
  end

  def create
    @user = User.new(user_params)

    # Optional: assign random password if none provided
    @user.password ||= SecureRandom.hex(8)
    @user.password_confirmation ||= @user.password

    if @user.save
      # @user.notifications.create(notification_type: 0)
      redirect_to users_path, notice: "User was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    @user = User.find(params[:id])

    # Only update password if entered
    if password_param.present?
      @user.update_with_password(password_params)
      bypass_sign_in(@user)
    end

    if @user.update(user_params.except(:password, :password_confirmation))
      # @user.notifications.create(notification_type: 1)
      redirect_to users_path, notice: "User was successfully updated."
    else
      flash[:alert] = 'Unable to update user.'
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @user.destroy!
    redirect_to users_path, notice: "User was successfully destroyed."
  end

  def change_password
    @user = current_user
  end

  def update_password
    @user = current_user

    if @user.update_with_password(password_params)
      bypass_sign_in(@user)
      flash[:notice] = 'Your Password was updated.'
      redirect_to authenticated_root_path
    else
      flash[:alert] = "#{@user.errors.full_messages.join(", ")}"
      render "change_password"
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_form_variables
    @user.project_users.build
    @projects = current_user.projects
  end

  def password_param
    params[:user][:password]
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end

  def user_params
    params.require(:user).permit(
      :first_name, :last_name, :email,
      :address, :address2, :city, :city2, :state, :state2, :zip, :zip2,
      :phone, :phone2, :phone3, :birthday, :best_time_to_call, :comment,
      :notes, :primary_address, :avatar, :subscribecode,
      :agency_id, :facilitator_id, :created_by_id, :updated_by_id,
      :confirmed, :inactive, :super_user, :legacy, :legacy_id
    )
  end
end
