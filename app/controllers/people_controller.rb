class PeopleController < ApplicationController
  include AhoyTracking
  before_action :set_person, only: %i[ show edit update destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(Person.includes(:user, :avatar_attachment, :sectorable_items,
                                                       user: [ :avatar_attachment, :organizations ])
                                             .references(:user))
    filtered = base_scope.search_by_params(params.to_unsafe_h)
                         .order(:first_name, :last_name)
    @count_display = filtered.size
    @people = filtered.paginate(page: params[:page], per_page: per_page)
  end

  def show
    @person = Person.find(params[:id]).decorate
    authorize! @person
    track_view(@person)
  end

  def new
    set_user
    @person = @user ? PersonFromUserService.new(user: @user).call : Person.new
    authorize! @person
    set_form_variables
  end

  def edit
    authorize! @person
    set_form_variables
  end

  def create
    @person = Person.new(person_params.except(:user_attributes))
    authorize! @person
    @person.user ||= (User.find(params[:person][:user_attributes][:id]) if params[:person][:user_attributes])

    respond_to do |format|
      if @person.save
        format.html { redirect_to @person, notice: "Person was successfully created." }
      else
        set_form_variables
        format.html { render :new, status: :unprocessable_content }
      end
    end
  end

  def update
    authorize! @person

    if params[:person][:_destroy] == "1"
      @person.avatar.purge
    end

    if @person.update(person_params)
      redirect_to @person, notice: "Person was successfully updated."
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @person
    @person.destroy

    respond_to do |format|
      format.html { redirect_to people_path, status: :see_other, notice: "Person was successfully destroyed." }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_person
    @person = Person.find(params[:id])
  end

  def set_user
    if params[:user_id].present?
      @user ||= User.find_by(id: params[:user_id])
      if @user
        @person&.user ||= @user
        @user.person ||= @person
      end
    end
  end

  def set_form_variables
    set_user
    # @person.build_user if @person.user.blank? # Build a fresh one if missing
    if @person.user
      @person.user.organization_users.first || @person.user.organization_users.build
    end

    @all_sectors = Sector.published.order(:name)
    @current_sector_ids = @person.sectorable_items.pluck(:sector_id)

    organizations = if current_user&.super_user?
      Organization.active
    else
      current_user.organizations
    end
    @organizations_array = organizations.order(:name).pluck(:name, :id)
  end


  # Only allow a list of trusted parameters through.
  def person_params
    params.require(:person).permit(
      :avatar,
      :first_name, :last_name,
      :email, :email_type,
      :email_2, :email_2_type,
      :street_address, :city, :state, :zip, :country, :mailing_address_type,
      :best_time_to_call,
      :date_of_birth,
      :bio, :notes,
      :display_name_preference,
      :pronouns,
      :profile_show_name_preference,
      :profile_is_searchable,
      :profile_show_pronouns,
      :profile_show_bio,
      :profile_show_email,
      :profile_show_phone,
      :profile_show_member_since,
      :profile_show_sectors,
      :profile_show_affiliations,
      :profile_show_social_media,
      :profile_show_events_registered,
      :profile_show_stories,
      :profile_show_story_ideas,
      :profile_show_workshop_variations,
      :profile_show_workshop_variation_ideas,
      :profile_show_workshops,
      :profile_show_workshop_ideas,
      :profile_show_workshop_logs,
      :published,
      :member_since,
      :linked_in_url,
      :facebook_url,
      :instagram_url,
      :youtube_url,
      :twitter_url,
      :created_by_id, :updated_by_id,
      sectorable_items_attributes: [ :id, :sector_id, :is_leader, :_destroy ],
      addresses_attributes: [
        :id,
        :address_type,
        :street_address,
        :city,
        :state,
        :zip_code,
        :country,
        :county,
        :district,
        :locality,
        :phone,
        :inactive,
        :_destroy
      ],
      contact_methods_attributes: [
        :id,
        :address_id,
        :contactable_id,
        :contactable_type,
        :contact_type,
        :kind,
        :value,
        :is_primary,
        :inactive,
        :_destroy
      ],
      user_attributes: [
        :id, :person_id,
        :first_name,
        :last_name,
        :email,
        :birthday,
        :inactive,
        :super_user,
        :phone,
        :phone2,
        :phone3,
        :best_time_to_call,
        :address,
        :city,
        :state,
        :zip,
        :address2,
        :city2,
        :state2,
        :zip2,
        :notes,
        organization_users_attributes: [
          :id,
          :organization_id,
          :position,
          :title,
          :inactive,
          :_destroy
        ]
      ],
    )
  end
end
