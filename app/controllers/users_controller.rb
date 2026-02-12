class UsersController < ApplicationController
  before_action :set_user, only: [ :show, :edit, :update, :destroy,
                                   :generate_person, :toggle_lock_status, :confirm_email,
                                   :send_welcome_instructions, :send_reset_password_instructions ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(User.includes(:avatar_attachment => :blob,
                                                person: { avatar_attachment: :blob }))
    filtered = base_scope.search_by_params(params).order(:first_name, :last_name)
    @users_count = filtered.count
    @users = filtered.paginate(page: params[:page], per_page: per_page)
  end

  def show
    authorize! @user
    @user = User.find(params[:id]).decorate
  end

  def new
    @user = User.new
    authorize! @user
    set_form_variables
  end

  def edit
    authorize! @user
    set_form_variables
  end

  def create
    @user = User.new(user_params)
    authorize! @user

    # do NOT have Devise send confirmation email - we'll handle that manually after creation via send_welcome_instructions
    @user.skip_confirmation_notification!

    # Optional: assign random password if none provided
    @user.password ||= SecureRandom.hex(8)
    @user.password_confirmation ||= @user.password

    # assign person
    person_id = params[:person_id].presence || params.dig(:user, :person_id).presence
    @user.person = Person.find(person_id) if person_id

    if @user.save
      # Generate welcome instructions token so that the welcome email set password and confirm email in one step
      @user.set_welcome_instructions_token!

      # @user.notifications.create(notification_type: 0)
      redirect_to users_path(search: @user.email), notice: "User was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @user

    # Only update password if entered
    if password_param.present?
      @user.update_with_password(password_params)
      bypass_sign_in(@user)
    end

    if @user.update(user_params.except(:password, :password_confirmation))
      # @user.notifications.create(notification_type: 1)
      redirect_to users_path, notice: "User was successfully updated."
    else
      flash[:alert] = "Unable to update user."
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @user
    @user.destroy!
    redirect_to users_path, notice: "User was successfully destroyed."
  end

  # ---------------------------------------------------------
  # PASSWORD
  # ---------------------------------------------------------

  def change_password
    @user = current_user
    authorize! @user
  end

  def update_password
    @user = current_user
    authorize! @user

    if @user.update_with_password(password_params)
      Analytics::AhoyTracker.track_auth_event(
        "auth.password_changed",
        user: @user
      )
      bypass_sign_in(@user)
      redirect_to root_path, notice: "Your Password was updated."
    else
      flash[:alert] = @user.errors.full_messages.join(", ")
      render :change_password
    end
  end

  # ---------------------------------------------------------
  # PERSON
  # ---------------------------------------------------------
  def generate_person
    authorize! @user

    if @user.person.present?
      redirect_to @user.person and return
    else
      @person = PersonFromUserService.new(user: @user).call
      if @person.save
        redirect_to @person, notice: "Person was successfully created for this user." and return
      else
        redirect_to @user, alert: "Unable to create person: #{@person.errors.full_messages.join(", ")}" and return
      end
    end
  end

  # ---------------------------------------------------------
  # RESET PASSWORD
  # ---------------------------------------------------------

  def send_reset_password_instructions
    authorize! @user
    @user.send_reset_password_instructions
    redirect_to users_path, notice: "Reset password instructions sent to #{@user.email}."
  end

  # ---------------------------------------------------------
  # LOCK / UNLOCK
  # ---------------------------------------------------------

  def toggle_lock_status
    authorize! @user, to: :toggle_lock_status?

    if @user.locked_at.present?
      # Unlock the user
      @user.update(locked_at: nil, failed_attempts: 0)
      message = "User has been unlocked."
    else
      # Lock the user
      @user.update(locked_at: Time.current)
      message = "User has been locked."
    end

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = message }
      format.html { redirect_to edit_user_path(@user), notice: message }
    end
  end

  # ---------------------------------------------------------
  # CONFIRM EMAIL
  # ---------------------------------------------------------

  def confirm_email
    authorize! @user, to: :confirm_email?

    if @user.confirmed_at.present?
      message = "Email is already confirmed."
    else
      @user.update(confirmed_at: Time.current)
      message = "Email has been manually confirmed."
    end

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = message }
      format.html { redirect_to edit_user_path(@user), notice: message }
    end
  end

  # ---------------------------------------------------------
  # SEND INVITATION
  # ---------------------------------------------------------
  def send_welcome_instructions
    authorize! @user, to: :send_welcome_instructions?

    @user.set_welcome_instructions_token!
    @user.save!
    @user.update(welcome_instructions_sent_at: Time.current)
    @user.send_confirmation_instructions

    redirect_back_or_to users_path,
                        notice: "Invitation sent to #{@user.email}."
  end

  # =========================================================
  # PRIVATE
  # =========================================================

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_person
    @person = @user.person || (Person.where(id: params[:person_id]).first if params[:person_id].present?)
  end

  def set_form_variables
    set_person
    @user.organization_users.first || @user.organization_users.build
    organizations = authorized_scope(Organization.all)
    @organizations_array = organizations.order(:name).pluck(:name, :id)
  end

  def password_param
    params.dig(:user, :password)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end

  def user_params
    params.require(:user).permit(
      :email, :comment, :person_id, :inactive, :primary_address, :time_zone, :super_user,

      ##### legacy to remove later
      :agency_id, :legacy, :legacy_id, :subscribecode, :avatar, :first_name, :last_name, # legacy to remove later
      :address, :address2, :city, :city2, :state, :state2, :zip, :zip2, # legacy to remove later
      :phone, :phone2, :phone3, :birthday, :best_time_to_call, :notes, # legacy to remove later
      #####

      organization_users_attributes: [ :id, :organization_id, :position, :title, :inactive, :_destroy ],
    )
  end
end
