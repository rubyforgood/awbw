class OrganizationsController < ApplicationController
  include AhoyTracking, TagAssignable
  before_action :set_organization, only: [ :show, :edit, :update, :destroy, :populations_served ]

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(Organization.includes(
        :windows_type, :organization_status, :organization_type, :sectors, :addresses,
        { categorizable_items: { category: :category_type } },
        logo_attachment: :blob
      ))
      filtered = base_scope.search_by_params(params).order(:name)
      @organizations_count = filtered.count
      @active_people_count = Affiliation.active.where(organization_id: filtered.select(:id)).count("DISTINCT person_id, organization_id")
      @organizations = filtered.paginate(page: params[:page], per_page: per_page)
      org_ids = @organizations.map(&:id)
      @affiliated_since = Affiliation.where(organization_id: org_ids)
                                            .group(:organization_id)
                                            .minimum(:start_date)
      @active_people_counts = Affiliation.active
                                                .where(organization_id: org_ids)
                                                .group(:organization_id)
                                                .distinct
                                                .count(:person_id)
      @program_statuses = Organization.program_statuses_by_id(org_ids)

      render :organizations_results
    else
      set_index_variables
      render :index
    end
  end

  def show
    authorize! @organization

    if turbo_frame_request? && params[:section] == "events"
      events = Event.where(id: @organization.event_registrations.active.select(:event_id))
                    .includes(:primary_asset)
                    .order(start_date: :desc)
                    .paginate(page: params[:page], per_page: 9)
      return render partial: "organizations/sections/events", locals: { organization: @organization, events: events }
    end

    track_view(@organization)

    workshop_logs = WorkshopLog.where(organization_id: @organization.id)
    @month_year_options = workshop_logs.group("DATE_FORMAT(COALESCE(workshop_held_on, created_at, NOW()), '%Y-%m')")
                                       .select("DATE_FORMAT(COALESCE(workshop_held_on, created_at, NOW()), '%Y-%m') AS ym,
       MAX(COALESCE(workshop_held_on, created_at)) AS max_dt")
                                       .order("max_dt DESC")
                                       .map { |record| [ Date.strptime(record.ym, "%Y-%m").strftime("%B %Y"), record.ym ] }

    @year_options = workshop_logs.pluck(
      Arel.sql("DISTINCT EXTRACT(YEAR FROM COALESCE(workshop_held_on, created_at, NOW()))")
    ).sort.reverse
    @organizations = Organization.where(id: @organization.id)
    @per_page = params[:per_page] || 10
    @workshop_logs_unpaginated = workshop_logs
                                 .includes(:workshop, :windows_type, created_by: :person)
                                 .order(workshop_held_on: :desc, created_at: :desc)
    @workshop_logs_count = @workshop_logs_unpaginated.count
    @workshop_logs = @workshop_logs_unpaginated.paginate(page: params[:page], per_page: @per_page)

    # Pre-compute grand totals to avoid expensive query in view
    @grand_totals = @workshop_logs_unpaginated.pick(
      Arel.sql("COALESCE(SUM(children_ongoing),0)"),
      Arel.sql("COALESCE(SUM(teens_ongoing),0)"),
      Arel.sql("COALESCE(SUM(adults_ongoing),0)"),
      Arel.sql("COALESCE(SUM(children_first_time),0)"),
      Arel.sql("COALESCE(SUM(teens_first_time),0)"),
      Arel.sql("COALESCE(SUM(adults_first_time),0)")
    ) || [ 0, 0, 0, 0, 0, 0 ]

    # Cache filter options to avoid duplicate queries
    @workshops = Workshop.joins(:windows_type)
                         .where(id: workshop_logs.where.not(workshop_id: nil).select(:workshop_id))
                         .select("workshops.id, workshops.title, workshops.windows_type_id, windows_types.name")
                         .order("workshops.title ASC, windows_types.name ASC")
    @users = User.where(id: workshop_logs.where.not(created_by_id: nil).select(:created_by_id))
                  .joins(:person)
                  .select("users.id, users.person_id, users.email, people.first_name, people.last_name")
                  .order("people.first_name, people.last_name")
  end

  def new
    @organization = Organization.new
    authorize! @organization
    set_form_variables
  end

  def edit
    authorize! @organization
    set_form_variables
  end

  def create
    @organization = Organization.new(organization_params)
    authorize! @organization

    unless params[:skip_duplicate_check].present?
      @duplicates = find_duplicate_organizations(@organization.name)
      if @duplicates.any?
        @name = @organization.name
        @blocked = @duplicates.any? { |d| d[:blocked] }
        set_form_variables
        respond_to do |format|
          format.html { render :new, status: :unprocessable_content }
          format.turbo_stream
        end
        return
      end
    end

    if @organization.save
      assign_associations(@organization) if params.dig(:organization, :category_ids)
      redirect_to @organization, notice: "Organization was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @organization
    @organization.assign_attributes(organization_params)
    @organization.comments.select(&:new_record?).each { |c| c.created_by = current_user; c.updated_by = current_user }
    @organization.comments.select { |c| c.persisted? && c.body_changed? }.each { |c| c.updated_by = current_user }

    if @organization.save
      assign_associations(@organization) if params.dig(:organization, :category_ids)
      redirect_to organization_path(@organization), notice: "Organization was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @organization

    if @organization.destroy
      redirect_to organizations_path, notice: "Organization was successfully destroyed."
    else
      redirect_to edit_organization_path(@organization), alert: "Unable to delete this organization: #{@organization.errors.full_messages.to_sentence}."
    end
  rescue ActiveRecord::InvalidForeignKey
    redirect_to edit_organization_path(@organization), alert: "Unable to delete this organization because it has associated records that cannot be removed."
  end

  def check_duplicates
    authorize!

    @name = params[:name]
    @duplicates = find_duplicate_organizations(@name)
    @blocked = @duplicates.any? { |d| d[:blocked] }
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @organization_statuses = OrganizationStatus.all
    @sectors_collection = Sector.published.order(:name).pluck(:name, :id)
    @current_sector_ids = @organization.sectorable_items.map(&:sector_id)

    if @organization.persisted? && @organization.errors.empty?
      affiliations = @organization.affiliations
      affiliations = affiliations.includes(:person) unless affiliations.loaded?
      sorted = affiliations.to_a
                             .sort_by { |affiliation|
                               expired = affiliation.inactive? || (affiliation.end_date.present? && affiliation.end_date < Date.current)
                               [ expired ? 1 : 0,
                                 affiliation.person&.first_name.to_s.downcase,
                                 affiliation.person&.last_name.to_s.downcase ]
                             }
      @organization.affiliations.proxy_association.target.replace(sorted)
    end

    @org_categories_grouped = Category
      .includes(:category_type)
      .published
      .order(:position, :name)
      .group_by(&:category_type)
      .select { |type, _| type&.profile_specific? }
      .sort_by { |type, _| type&.name.to_s.downcase }
  end

  def set_index_variables
    @organization_statuses = OrganizationStatus.all
  end

  def populations_served
    authorize! @organization

    people = @organization.users.includes(:person).map(&:person).compact

    sector_counts = Hash.new(0)
    people.each do |person|
      primary_sector = person.sectors.first
      sector_counts[primary_sector] += 1 if primary_sector
    end
    @sectors_by_people = sector_counts.sort_by { |_sector, count| -count }
  end

  private

  def set_organization
    @organization = Organization.includes(
      :organization_status, :organization_type, :windows_type, :addresses,
      :categorizable_items,
      { comments: [ :created_by, :updated_by ] },
      { sectorable_items: :sector },
      affiliations: :person
    ).find(params[:id])
  end

  # Strong parameters
  def organization_params
    params.require(:organization).permit(
      :name, :description, :start_date, :end_date, :mission_vision_values,
      :organization_type_id, :agency_type_other, :filemaker_code, :logo, :notes, :email, :website_url,
      :organization_status_id, :location_id, :windows_type_id,
      :profile_show_sectors, :profile_show_email, :profile_show_phone,
      :profile_show_website, :profile_show_description, :profile_show_workshops,
      :profile_show_stories, :profile_show_events_registered, :profile_show_workshop_logs,
      category_ids: [],
      sectorable_items_attributes: [
        :id,
        :sector_id,
        :_destroy
      ],
      affiliations_attributes: [
        :id,
        :person_id,
        :inactive,
        :primary_contact,
        :title,
        :start_date,
        :end_date,
        :organization_address_id,
        :_destroy
      ],
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      addresses_attributes: [
        :id,
        :address_type,
        :primary,
        :inactive,
        :phone,
        :street_address,
        :city,
        :state,
        :zip_code,
        :county,
        :country,
        :district,
        :locality,
        :la_city_council_district,
        :la_supervisorial_district,
        :la_service_planning_area,
        :_destroy
      ]
    )
  end

  def find_duplicate_organizations(name)
    return [] if name.blank?

    normalized = normalize(name)
    input_words = words(name)

    # fallback if all words were ignored
    search_word = input_words.first || name.to_s.downcase

    candidates = Organization
      .where("LOWER(name) LIKE ?", "%#{search_word}%")
      .select(:id, :name)

    candidates.map do |org|
      org_normalized = normalize(org.name)

      exact = org_normalized == normalized

      partial =
        org_normalized.include?(normalized) ||
        normalized.include?(org_normalized)

      similar = exact || partial

      {
        id: org.id,
        name: org.name,
        match_type: exact ? "exact" : "approximate",
        name_match: similar,
        blocked: exact
      }
    end.select { |d| d[:name_match] }
  end

  def normalize(name)
    name.to_s.downcase.gsub(/[^a-z0-9]/, "")
  end

  IGNORE_WORDS_LAST_ONLY = %w[combined childrens adult]
  IGNORE_WORDS_ALWAYS = %w[of the and inc]

  def words(name)
    all_words = name
      .to_s
      .downcase
      .gsub(/[^a-z0-9\s]/, "")
      .split

    last_word = all_words.last

    all_words.reject do |w|
      IGNORE_WORDS_ALWAYS.include?(w) ||
        (IGNORE_WORDS_LAST_ONLY.include?(w) && w != last_word)
    end
  end
end
