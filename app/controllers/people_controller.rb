class PeopleController < ApplicationController
  include AhoyTracking
  before_action :set_person, only: %i[ show edit update destroy ]

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(Person.includes(
        :avatar_attachment,
        :user,
        sectorable_items: :sector,
        affiliations: :organization
      ).references(:user))
      filtered = base_scope.search_by_params(params.to_unsafe_h)
                           .order(:first_name, :last_name)
      @count_display = filtered.count
      @people = filtered.paginate(page: params[:page], per_page: per_page)
      ActiveRecord::Associations::Preloader.new(
        records: @people.map(&:user).compact,
        associations: [ :avatar_attachment ]
      ).call

      render :people_results
    else
      render :index
    end
  end

  def show
    authorize! @person
    @person = Person.includes(:avatar_attachment, :contact_methods, :user).find(params[:id]).decorate
    track_view(@person)

    # Handle paginated sections for Turbo Frame requests
    if turbo_frame_request?
      per_page = params[:section] == "stories" ? 8 : 9
      section = params[:section]

      case section
      when "workshops"
        @workshops = @person.user&.workshops&.order(created_at: :desc)&.paginate(page: params[:page], per_page: per_page) || []
        render partial: "people/sections/workshops", locals: { person: @person, workshops: @workshops }
      when "workshop_variations"
        @workshop_variations = @person.user&.workshop_variations_as_creator&.order(created_at: :desc)&.paginate(page: params[:page], per_page: per_page) || []
        render partial: "people/sections/workshop_variations", locals: { person: @person, workshop_variations: @workshop_variations }
      when "stories"
        story_ids = @person.user&.stories_as_creator&.pluck(:id).to_a + @person.stories_as_spotlighted_facilitator.pluck(:id)
        @stories = Story.where(id: story_ids).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/stories", locals: { person: @person, stories: @stories }
      when "events"
        @event_registrations = @person.event_registrations.includes(:event).order("events.start_date DESC").references(:events).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/events", locals: { person: @person, event_registrations: @event_registrations }
      when "workshop_ideas"
        @workshop_ideas = @person.user&.workshop_ideas_as_creator&.order(created_at: :desc)&.paginate(page: params[:page], per_page: per_page) || []
        render partial: "people/sections/workshop_ideas", locals: { person: @person, workshop_ideas: @workshop_ideas }
      when "story_ideas"
        @story_ideas = @person.user&.story_ideas_as_creator&.order(created_at: :desc)&.paginate(page: params[:page], per_page: per_page) || []
        render partial: "people/sections/story_ideas", locals: { person: @person, story_ideas: @story_ideas }
      when "workshop_logs"
        @workshop_logs = @person.user&.workshop_logs&.order(date: :desc, created_at: :desc)&.paginate(page: params[:page], per_page: per_page) || []
        render partial: "people/sections/workshop_logs", locals: { person: @person, workshop_logs: @workshop_logs }
      when "workshop_variation_ideas"
        @workshop_variation_ideas = @person.user&.workshop_variation_ideas_creator&.order(created_at: :desc)&.paginate(page: params[:page], per_page: per_page) || []
        render partial: "people/sections/workshop_variation_ideas", locals: { person: @person, workshop_variation_ideas: @workshop_variation_ideas }
      when "affiliations"
        @affiliations = @person.affiliations.active.includes(organization: :logo_attachment).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/affiliations", locals: { person: @person, affiliations: @affiliations }
      end
    end
  end

  def new
    set_user
    @person = @user ? PersonFromUserService.new(user: @user).call : Person.new
    @person.user = @user if @user
    authorize! @person
    set_form_variables
  end

  def edit
    @person = Person.includes(
      :user,
      :contact_methods,
      :addresses,
      { avatar_attachment: :blob },
      { comments: [ :created_by, :updated_by ] },
      { sectorable_items: :sector },
      affiliations: { organization: :logo_attachment }
    ).find(params[:id]).decorate
    authorize! @person
    set_form_variables
  end

  def create
    @person = Person.new(person_params.except(:user_attributes))
    authorize! @person
    @person.user ||= User.find_by(id: params[:user_id]) if params[:user_id].present?
    @person.user ||= User.find_by(id: params.dig(:person, :user_attributes, :id)) if params.dig(:person, :user_attributes, :id).present?
    if @person.user && person_params[:user_attributes].present?
      @person.user.assign_attributes(person_params[:user_attributes].except(:id))
    end

    unless params[:skip_duplicate_check].present?
      duplicates = find_duplicate_people(
        @person.first_name,
        @person.last_name,
        @person.email
      )
      if duplicates.any?
        redirect_to check_duplicates_people_path(
          first_name: @person.first_name,
          last_name: @person.last_name,
          email: @person.email
        )
        return
      end
    end

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

    @person.assign_attributes(person_params)
    @person.comments.select(&:new_record?).each { |c| c.created_by = current_user; c.updated_by = current_user }
    @person.comments.select(&:changed?).each { |c| c.updated_by = current_user }

    if @person.save
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

  def check_duplicates
    authorize!

    @first_name = params[:first_name]
    @last_name = params[:last_name]
    @email = params[:email]
    @duplicates = find_duplicate_people(@first_name, @last_name, @email)
    @blocked = @duplicates.any? { |d| d[:blocked] }
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
    if @person.persisted? && @person.errors.empty?
      affiliations = @person.affiliations
      affiliations = affiliations.includes(:organization) unless affiliations.loaded?
      sorted = affiliations.to_a
                      .sort_by { |affiliation|
                        expired = affiliation.inactive? || (affiliation.end_date.present? && affiliation.end_date < Date.current)
                        [ expired ? 1 : 0,
                          affiliation.organization&.name.to_s.downcase ]
                      }
      @person.affiliations.proxy_association.target.replace(sorted)
    end
    @person.affiliations.build if @person.affiliations.empty?

    @all_sectors = Sector.published.order(:name)
    @sectors_collection = @all_sectors.pluck(:name, :id)
    @current_sector_ids = @person.sectorable_items.map(&:sector_id)

    @organizations_array = authorized_scope(Organization.all, as: :affiliated).order(:name).pluck(:name, :id)
  end

  def find_duplicate_people(first_name, last_name, email)
    duplicates = []
    duplicate_ids = Set.new

    # Check for name matches (exact + nickname variants)
    # Normalize removes periods and extra whitespace: "J. R." -> "jr"
    if first_name.presence && last_name.presence
      first_variants = NicknameMap.variants_for(first_name)
      normalized_last = NicknameMap.normalize(last_name)
      normalized_first = NicknameMap.normalize(first_name)

      name_matches = Person.includes(:user)
                           .where("REPLACE(REPLACE(LOWER(last_name), '.', ''), ' ', '') = ?", normalized_last)
                           .where("REPLACE(REPLACE(LOWER(first_name), '.', ''), ' ', '') IN (?)", first_variants)
                           .limit(10)

      name_matches.each do |person|
        next if duplicate_ids.include?(person.id)

        duplicate_ids.add(person.id)
        exact_name = NicknameMap.normalize(person.first_name) == normalized_first
        duplicates << format_duplicate(person, exact: exact_name, entered_email: email)
      end
    end

    # Check for email matches (skip example.com)
    # Only match person.email when person has no user (otherwise it's a stale copy of user.email)
    if email.presence && !email.downcase.end_with?("@example.com") && duplicates.size < 10
      email_lower = email.downcase
      email_query = Person.includes(:user)
                          .left_joins(:user)
                          .where(
                            "(users.id IS NULL AND LOWER(people.email) = :email) OR LOWER(people.email_2) = :email OR LOWER(users.email) = :email",
                            email: email_lower
                          )
                          .limit(10)

      email_query.each do |person|
        next if duplicate_ids.include?(person.id)

        duplicate_ids.add(person.id)
        name_matches = first_name.present? && last_name.present? &&
          NicknameMap.normalize(person.first_name) == NicknameMap.normalize(first_name) &&
          NicknameMap.normalize(person.last_name) == NicknameMap.normalize(last_name)
        duplicates << format_duplicate(person, exact: name_matches, entered_email: email)
        break if duplicates.size >= 10
      end
    end

    sort_order = { "exact" => 0, "name" => 1, "approximate" => 2, "email" => 3, "nickname" => 4 }
    duplicates.sort_by { |d| [ d[:blocked] ? -1 : 0, sort_order[d[:match_type]] || 4 ] }
  end

  def format_duplicate(person, exact: true, entered_email: nil)
    labeled_emails = []
    # Skip person.email when person has a user (it's a stale copy of user.email)
    labeled_emails << { label: "Email", value: person.email } if person.email.present? && person.user.blank?
    labeled_emails << { label: "Secondary email", value: person.email_2 } if person.email_2.present?
    labeled_emails << { label: "User email", value: person.user.email } if person.user&.email.present?
    emails = labeled_emails.map { |e| e[:value] }.uniq
    any_email_match = entered_email.present? &&
      emails.any? { |e| e.downcase == entered_email.downcase }
    primary_email_match = exact && entered_email.present? &&
      person.email.present? && person.email.downcase == entered_email.downcase
    secondary_email_match = exact && any_email_match && !primary_email_match

    match_type = if primary_email_match
      "exact"
    elsif secondary_email_match
      "approximate"
    elsif !exact && any_email_match
      "email"
    elsif exact
      "name"
    else
      "nickname"
    end

    {
      id: person.id,
      name: person.full_name,
      labeled_emails: labeled_emails,
      match_type: match_type,
      name_match: exact,
      blocked: primary_email_match
    }
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
        :primary,
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
        :primary,
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
        :time_zone
      ],
      affiliations_attributes: [
        :id,
        :organization_id,
        :position,
        :title,
        :inactive,
        :primary_contact,
        :start_date,
        :end_date,
        :_destroy
      ],
      comments_attributes: [ :id, :body ],
    )
  end
end
