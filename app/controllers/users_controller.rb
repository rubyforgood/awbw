class UsersController < ApplicationController
  before_action :set_user, only: [ :show, :edit, :update, :destroy,
                                   :generate_person, :toggle_lock_status, :confirm_email,
                                   :send_welcome_instructions, :send_reset_password_instructions ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(User.includes(:created_by, :updated_by,
                                                avatar_attachment: :blob,
                                                person: { avatar_attachment: :blob }))
    filtered = base_scope.search_by_params(params).order(:first_name, :last_name)
    @users_count = filtered.count
    @users = filtered.paginate(page: params[:page], per_page: per_page)
  end

  def show
    authorize! @user
    @user = User.find(params[:id]).decorate
    @comments = @user.comments.includes(:created_by).newest_first.paginate(page: params[:comments_page], per_page: 5)

    user_auth_events = Ahoy::Event
      .where("name LIKE 'auth.%' OR name LIKE 'update.user'")
      .where(
        "(CAST(JSON_EXTRACT(properties, '$.record_id') AS UNSIGNED) = :id AND JSON_UNQUOTE(JSON_EXTRACT(properties, '$.record_type')) = 'User') OR " \
        "(CAST(JSON_EXTRACT(properties, '$.resource_id') AS UNSIGNED) = :id AND JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_type')) = 'User')",
        id: @user.id
      )

    @last_admin_event = user_auth_events.where(name: %w[auth.admin_granted auth.admin_revoked]).order(time: :desc).first
    @last_lock_event = user_auth_events.where(name: %w[auth.account_locked auth.account_unlocked]).order(time: :desc).first

    @account_events = user_auth_events
      .includes(:user)
      .order(time: :desc)
      .paginate(page: params[:page], per_page: 10)
  end

  def new
    @user = User.new
    authorize! @user
    set_form_variables
  end

  def edit
    @user = User.includes(comments: [ :created_by, :updated_by ]).find(params[:id])
    authorize! @user
    set_form_variables
  end

  def create
    @user = User.new(user_params)
    authorize! @user

    # Check for duplicate email before saving
    unless params[:skip_duplicate_check].present?
      email = @user.email
      if email.present? && !email.downcase.end_with?("@example.com")
        duplicates = find_duplicate_users(email)
        if duplicates.any?
          redirect_to check_duplicates_users_path(email: email, person_id: params[:person_id].presence || params.dig(:user, :person_id).presence)
          return
        end
      end
    end

    # do NOT have Devise send confirmation email - we'll handle that manually after creation via send_welcome_instructions
    @user.skip_confirmation_notification!

    # Optional: assign random password if none provided
    @user.password ||= SecureRandom.hex(8)
    @user.password_confirmation ||= @user.password

    # assign person
    person_id = params[:person_id].presence || params.dig(:user, :person_id).presence
    @user.person = Person.find(person_id) if person_id
    @user.created_by = current_user
    @user.updated_by = current_user

    if @user.save
      # @user.notifications.create(notification_type: 0)
      redirect_to users_path(search: @user.email), notice: "User was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def check_duplicates
    authorize!

    @email = params[:email]
    @person_id = params[:person_id]
    @duplicates = find_duplicate_users(@email)
    @blocked = @duplicates.any? { |d| d[:blocked] }
  end

  def update
    authorize! @user

    # Only update password if entered
    if password_param.present?
      @user.update_with_password(password_params)
      bypass_sign_in(@user)
    end

    @user.assign_attributes(user_params.except(:password, :password_confirmation))
    @user.updated_by = current_user
    @user.comments.select(&:new_record?).each { |c| c.created_by = current_user }
    @user.comments.select(&:changed?).each { |c| c.updated_by = current_user }

    if @user.save
      bypass_sign_in(@user) if @user == current_user
      notice = "User was successfully updated."
      notice += " A confirmation email has been sent to #{@user.unconfirmed_email}." if @user.unconfirmed_email.present? && @user.saved_change_to_unconfirmed_email?
      redirect_to users_path, notice: notice
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
      respond_to do |format|
        format.html { render :change_password }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "password-errors",
            partial: "users/password_errors",
            locals: { user: @user }
          )
        end
      end
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
    @user.update(welcome_instructions_sent_at: Time.current)
    @user.send_confirmation_instructions

    redirect_to users_path(search: params[:search],
                           super_user: params[:super_user],
                           inactive: params[:inactive],
                           page: params[:page],
                           number_of_items_per_page: params[:number_of_items_per_page]),
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
    @user.person.organization_people.first || @user.person.organization_people.build if @user.person
    organizations = authorized_scope(Organization.all)
    @organizations_array = organizations.order(:name).pluck(:name, :id)
  end

  def password_param
    params.dig(:user, :password)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end

  def find_duplicate_users(email)
    return [] if email.blank?

    email_lower = email.downcase
    duplicates = []

    # Check existing users with same email
    User.where("LOWER(email) = ?", email_lower).includes(:person).limit(10).each do |user|
      duplicates << {
        id: user.id,
        name: user.person&.full_name || "#{user.first_name} #{user.last_name}".strip,
        person_id: user.person_id,
        email: user.email,
        type: "user",
        blocked: true
      }
    end

    # Check people with matching email or secondary email
    already_found_person_ids = duplicates.map { |d| d[:person_id] }.compact
    people_scope = Person.includes(:user)
          .where("LOWER(people.email) = :email OR LOWER(people.email_2) = :email", email: email_lower)
    people_scope = people_scope.where.not(id: already_found_person_ids) if already_found_person_ids.any?
    people_scope.limit(10).each do |person|
      primary_match = person.email&.downcase == email_lower
      duplicates << {
        id: person.id,
        name: person.full_name,
        email: primary_match ? person.email : person.email_2,
        email_field: primary_match ? "primary" : "secondary",
        has_user: person.user.present?,
        user_email: person.user&.email,
        type: "person",
        blocked: false
      }
    end

    duplicates
  end

  def user_params
    params.require(:user).permit(
      :email, :comment, :person_id, :inactive, :locked, :primary_address, :time_zone, :super_user,

      ##### legacy to remove later
      :agency_id, :legacy, :legacy_id, :subscribecode, :avatar, :first_name, :last_name, # legacy to remove later
      :address, :address2, :city, :city2, :state, :state2, :zip, :zip2, # legacy to remove later
      :phone, :phone2, :phone3, :birthday, :best_time_to_call, :notes, # legacy to remove later
      #####

      organization_people_attributes: [ :id, :organization_id, :position, :title, :inactive, :primary_contact, :start_date, :end_date, :_destroy ],
      comments_attributes: [ :id, :body ],
    )
  end
end
