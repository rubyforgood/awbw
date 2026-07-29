class UsersController < ApplicationController
  before_action :set_user, only: [ :show, :edit, :update, :destroy,
                                   :toggle_lock_status, :confirm_email,
                                   :send_welcome_instructions, :send_reset_password_instructions,
                                   :confirm_email_change, :process_email_change,
                                   :confirm_email_manual, :process_email_manual ]

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(User.includes(:created_by, :updated_by, :welcome_instructions_sent_by,
                                                  person: { avatar_attachment: :blob }))
      filtered = base_scope.search_by_params(params).order(:first_name, :last_name)
      @users_count = filtered.count
      @users = filtered.paginate(page: params[:page], per_page: per_page)

      render :users_results
    else
      render :index
    end
  end

  def show
    authorize! @user
    @user = User.find(params[:id]).decorate

    if turbo_frame_request? && params[:section] == "account_activity"
      @account_events = account_events_for(@user, search: params[:search], by_user_id: params[:by_user_id])
                          .paginate(page: params[:page], per_page: 10)
      by_user_options = account_event_user_options(@user)
      render partial: "users/sections/account_activity",
             locals: { user: @user, account_events: @account_events, by_user_options: by_user_options }
      return
    end

    @comments = @user.comments.includes(:created_by).newest_first.paginate(page: params[:comments_page], per_page: 5)

    user_auth_events = user_auth_events_base(@user)
    @last_admin_event = user_auth_events.where(name: %w[auth.admin_granted auth.admin_revoked]).order(time: :desc).first
    @last_lock_event = user_auth_events.where(name: %w[auth.account_locked auth.account_unlocked]).order(time: :desc).first

    # Fall back to ahoy events for created_by/updated_by if not set on the model
    unless @user.created_by
      create_event = Ahoy::Event.where(name: "create.user", resource_type: "User", resource_id: @user.id)
                                .order(time: :asc).first
      @created_by_fallback = create_event&.user
    end

    unless @user.updated_by
      update_event = Ahoy::Event.where(name: "update.user", resource_type: "User", resource_id: @user.id)
                                .order(time: :desc).first
      @updated_by_fallback = update_event&.user
    end
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
      @email = @user.email
      if @email.present? && !@email.downcase.end_with?("@example.com")
        @person_id = params[:person_id].presence || params.dig(:user, :person_id).presence || @user.person_id
        @duplicates = find_duplicate_users(@email, exclude_person_id: @person_id)
        if @duplicates.any?
          @blocked = @duplicates.any? { |d| d[:blocked] }
          set_form_variables
          respond_to do |format|
            format.html { render :new, status: :unprocessable_content }
            format.turbo_stream
          end
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
      if params[:event_registration_id].present?
        redirect_to edit_event_registration_path(params[:event_registration_id]), notice: "User was successfully created."
      else
        redirect_to @user, notice: "User was successfully created."
      end
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def check_duplicates
    authorize!

    @email = params[:email]
    @person_id = params[:person_id]
    @duplicates = find_duplicate_users(@email, exclude_person_id: @person_id)
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
    @user.comments.select(&:new_record?).each { |c| c.created_by = current_user; c.updated_by = current_user }
    @user.comments.select { |c| c.persisted? && c.body_changed? }.each { |c| c.updated_by = current_user }

    # Suppress Devise's automatic reconfirmation email so the interstitial can control it
    @user.skip_confirmation_notification!

    if @user.save
      bypass_sign_in(@user) if @user == current_user

      if current_user.super_user? && @user.saved_change_to_unconfirmed_email? && @user.unconfirmed_email.present?
        redirect_to confirm_email_change_user_path(@user)
        return
      end

      redirect_to @user, notice: "User was successfully updated."
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
  rescue ActiveRecord::InvalidForeignKey
    redirect_to @user, alert: "Unable to delete this user because they have associated records that cannot be removed."
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
  # EMAIL CHANGE INTERSTITIAL
  # ---------------------------------------------------------

  def confirm_email_change
    authorize! @user, to: :confirm_email_change?
  end

  def process_email_change
    authorize! @user, to: :process_email_change?

    result = UserServices::ProcessEmailChange.call(
      user: @user,
      send_confirmation: params[:send_confirmation] == "1",
      current_user: current_user
    )

    redirect_to @user, notice: result.summary
  end

  # ---------------------------------------------------------
  # MANUAL EMAIL CONFIRMATION INTERSTITIAL
  # ---------------------------------------------------------

  def confirm_email_manual
    authorize! @user, to: :confirm_email_manual?
  end

  def process_email_manual
    authorize! @user, to: :process_email_manual?

    result = UserServices::ProcessEmailManualConfirm.call(
      user: @user,
      action: params[:confirm_action],
      current_user: current_user
    )

    redirect_to @user, notice: result.summary
  end

  # ---------------------------------------------------------
  # SEND INVITATION
  # ---------------------------------------------------------
  def send_welcome_instructions
    authorize! @user, to: :send_welcome_instructions?

    # Sending the invite writes to the record (token + timestamps), so credit the
    # sender on updated_by too — otherwise "Last updated" attributes it to whoever
    # last edited the account, not who actually sent the invite.
    @user.updated_by = current_user
    @user.set_welcome_instructions_token!
    @user.update(welcome_instructions_sent_at: Time.current, welcome_instructions_sent_by: current_user)
    @user.send_confirmation_instructions

    redirect_to users_path(search: params[:search],
                           super_user: params[:super_user],
                           inactive: params[:inactive],
                           page: params[:page],
                           number_of_items_per_page: params[:number_of_items_per_page]),
                notice: "Invitation sent to #{@user.email}."
  end

  # Visual reference for admins triaging user account challenges
  def flow_diagram
    authorize!
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
    @user.person.affiliations.first || @user.person.affiliations.build if @user.person
    organizations = authorized_scope(Organization.all)
    @organizations_array = organizations.order(:name).pluck(:name, :id)
  end

  def user_auth_events_base(user)
    Ahoy::Event
      .where("name LIKE 'auth.%' OR name LIKE 'update.user'")
      .where(
        "(CAST(JSON_EXTRACT(properties, '$.record_id') AS UNSIGNED) = :id AND JSON_UNQUOTE(JSON_EXTRACT(properties, '$.record_type')) = 'User') OR " \
        "(CAST(JSON_EXTRACT(properties, '$.resource_id') AS UNSIGNED) = :id AND JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_type')) = 'User')",
        id: user.id
      )
  end

  def account_events_for(user, search: nil, by_user_id: nil)
    scope = user_auth_events_base(user).includes(:user).order(time: :desc)
    if search.present?
      q = "%#{search}%"
      scope = scope.where("ahoy_events.name LIKE :q OR CAST(ahoy_events.properties AS CHAR) LIKE :q", q: q)
    end
    scope = scope.where(user_id: by_user_id) if by_user_id.present?
    scope
  end

  def account_event_user_options(user)
    User.where(super_user: true).or(User.where(id: user.id))
        .order(:first_name, :last_name)
        .map { |u| [ u.name, u.id ] }
  end

  def password_param
    params.dig(:user, :password)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end

  def find_duplicate_users(email, exclude_person_id: nil)
    return [] if email.blank?

    email_lower = email.downcase
    duplicates = []

    # Check existing users with same email
    users_scope = User.where("LOWER(email) = ?", email_lower).includes(:person)
    users_scope = users_scope.where.not(person_id: exclude_person_id) if exclude_person_id
    users_scope.limit(10).each do |user|
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
    exclude_person_ids = duplicates.map { |d| d[:person_id] }.compact
    exclude_person_ids << exclude_person_id.to_i if exclude_person_id
    people_scope = Person.includes(:user)
          .where("LOWER(people.email) = :email OR LOWER(people.email_2) = :email", email: email_lower)
    people_scope = people_scope.where.not(id: exclude_person_ids) if exclude_person_ids.any?
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
      :email, :comment, :person_id, :inactive, :locked, :primary_address, :time_zone, :super_user, :favorite_event_id,

      ##### legacy to remove later
      :agency_id, :legacy, :legacy_id, :subscribecode, :first_name, :last_name, # legacy to remove later
      :address, :address2, :city, :city2, :state, :state2, :zip, :zip2, # legacy to remove later
      :phone, :phone2, :phone3, :birthday, :best_time_to_call, :notes, # legacy to remove later
      #####

      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      affiliations_attributes: [ :id, :organization_id, :position, :title, :inactive, :primary_contact, :start_date, :end_date, :_destroy ],
    )
  end
end
