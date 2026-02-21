class OrganizationsController < ApplicationController
  include AhoyTracking
  before_action :set_organization, only: [ :show, :edit, :update, :destroy, :populations_served ]

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(Organization.includes(:windows_type, :organization_status, :sectors, :addresses, logo_attachment: :blob))
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

      render :organization_results
    else
      set_index_variables
      render :index
    end
  end

  def show
    authorize! @organization
    track_view(@organization)

    workshop_logs = WorkshopLog.where(organization_id: @organization.id)
    @month_year_options = workshop_logs.group("DATE_FORMAT(COALESCE(date, created_at, NOW()), '%Y-%m')")
                                       .select("DATE_FORMAT(COALESCE(date, created_at, NOW()), '%Y-%m') AS ym,
       MAX(COALESCE(date, created_at)) AS max_dt")
                                       .order("max_dt DESC")
                                       .map { |record| [ Date.strptime(record.ym, "%Y-%m").strftime("%B %Y"), record.ym ] }

    @year_options = workshop_logs.pluck(
      Arel.sql("DISTINCT EXTRACT(YEAR FROM COALESCE(date, created_at, NOW()))")
    ).sort.reverse
    @organizations = Organization.where(id: @organization.id)
    @per_page = params[:per_page] || 10
    @workshop_logs_unpaginated = workshop_logs
                                 .includes(:user, :workshop, :windows_type)
                                 .order(date: :desc, created_at: :desc)
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
    logged_workshop_ids = workshop_logs.where.not(workshop_id: nil).distinct.pluck(:workshop_id)
    @workshops = Workshop.joins(:windows_type)
                         .where(id: logged_workshop_ids)
                         .select("workshops.id, workshops.title, windows_types.name")
                         .order("workshops.title ASC, windows_types.name ASC")
    logged_user_ids = workshop_logs.where.not(user_id: nil).distinct.pluck(:user_id)
    @users = User.where(id: logged_user_ids)
                 .includes(:person)
                 .select("users.id, users.person_id, users.email, people.first_name, people.last_name")
                 .order(Arel.sql("LOWER(people.first_name), LOWER(people.last_name), LOWER(users.email)"))
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

    if @organization.save
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
    @organization.comments.select(&:changed?).each { |c| c.updated_by = current_user }

    if @organization.save
      redirect_to organization_path(@organization), notice: "Organization was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @organization
    @organization.destroy!
    redirect_to organizations_path, notice: "Organization was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @organization_statuses = OrganizationStatus.all
    @sectors_collection = Sector.published.order(:name).pluck(:name, :id)
    @current_sector_ids = @organization.sectorable_items.map(&:sector_id)
    # Build array of [display_name, id] for person selection dropdown
    # Email priority matches Person#preferred_email: user.email > person.email > person.email_2
    @people_array = authorized_scope(Person.left_joins(:user))
                          .order(Arel.sql("LOWER(people.first_name), LOWER(people.last_name), LOWER(COALESCE(users.email, people.email, people.email_2))"))
                          .pluck(
                            :first_name,
                            :last_name,
                            :id,
                            Arel.sql("COALESCE(users.email, people.email, people.email_2)")
                          )
                          .map { |fn, ln, id, email|
                            [ "#{fn} #{ln}#{" (#{email})" if email.present?}", id ]
                          }

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
      :organization_status, :windows_type, :addresses,
      { comments: [ :created_by, :updated_by ] },
      { sectorable_items: :sector },
      affiliations: :person
    ).find(params[:id])
  end

  # Strong parameters
  def organization_params
    params.require(:organization).permit(
      :name, :description, :start_date, :end_date, :mission_vision_values,
      :agency_type, :agency_type_other, :internal_id, :logo, :notes, :email, :website_url,
      :organization_status_id, :location_id, :windows_type_id,
      :profile_show_sectors, :profile_show_email, :profile_show_phone,
      :profile_show_website, :profile_show_description, :profile_show_workshops,
      :profile_show_stories, :profile_show_events_registered, :profile_show_workshop_logs,
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
        :_destroy
      ],
      comments_attributes: [ :id, :body ],
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
end
