class OrganizationsController < ApplicationController
  include AhoyTracking, Dedupable
  before_action :set_organization, only: [ :show, :edit, :update, :destroy, :populations_served ]

  # The "Published content" sections, each gated by its profile_show_* flag.
  PUBLISHED_SECTIONS = %w[workshops stories].freeze

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(Organization.includes(
        :organization_status, :addresses,
        # Feeds the per-row sector and age-group roll-ups.
        { affiliations: { person: Organization::PEOPLE_TAGGINGS } },
        logo_attachment: :blob
      ))
      filtered = base_scope.search_by_params(params).order(:name)
      @organizations_count = filtered.count
      @active_people_count = Affiliation.active.where(organization_id: filtered.select(:id)).count("DISTINCT person_id, organization_id")
      @organizations = filtered.paginate(page: params[:page], per_page: per_page)
      org_ids = @organizations.map(&:id)
      @program_since_display = @organizations.to_h { |org| [ org.id, org.decorate.program_since_display ] }
      @active_people_counts = Affiliation.active
                                                .where(organization_id: org_ids)
                                                .group(:organization_id)
                                                .distinct
                                                .count(:person_id)

      render :organizations_results
    else
      set_index_variables
      render :index
    end
  end

  def show
    authorize! @organization

    if turbo_frame_request? && params[:section] == "events"
      events = authorized_scope(
        Event.where(id: @organization.event_registrations.active.select(:event_id))
             .includes(:primary_asset)
             .order(start_date: :desc)
      ).paginate(page: params[:page], per_page: 9)
      return render partial: "organizations/sections/events", locals: { organization: @organization, events: events }
    end

    # Later pages of the published-content sections swap in through their frames.
    # The section name comes from the constant, never the param, so the render path is fixed.
    section = PUBLISHED_SECTIONS.find { |name| name == params[:section] }
    if turbo_frame_request? && section
      # A section the org hid stays hidden from a crafted ?section= request.
      authorize! @organization, to: :manage? unless @organization.public_send(:"profile_show_#{section}?")
      records = published_section_records(section, page: params[:page])
      return render partial: "organizations/sections/#{section}", locals: { section.to_sym => records }
    end

    track_view(@organization)

    PUBLISHED_SECTIONS.each do |section|
      next unless @organization.public_send(:"profile_show_#{section}?")
      instance_variable_set(:"@published_#{section}", published_section_records(section, page: 1))
    end

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
      redirect_to @organization, notice: "Organization was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @organization
    @organization.assign_attributes(organization_params)

    if @organization.save
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
    if @organization.persisted? && @organization.errors.empty?
      affiliations = @organization.affiliations
      affiliations = affiliations.includes(:person) unless affiliations.loaded?
      sorted = affiliations.to_a
                             .sort_by { |affiliation|
                               [ affiliation.active? ? 0 : 1,
                                 affiliation.person&.first_name.to_s.downcase,
                                 affiliation.person&.last_name.to_s.downcase ]
                             }
      @organization.affiliations.proxy_association.target.replace(sorted)
    end

    # Drives the edit form's per-event program-status chips. Trainings only —
    # program status is meaningless for other events (ADR-0001 D6).
    @organization_events = if @organization.persisted?
      authorized_scope(
        Event.where(id: @organization.event_registrations.active.select(:event_id))
             .where(facilitator_training: true)
             .order(start_date: :desc)
      )
    else
      Event.none
    end

    # Trainings the org only ever registered for inactively — a no-show,
    # cancellation, or transfer out with no active registration there. These earn a
    # red attendance chip on the edit form instead of a program-status one, since a
    # no-show confers no facilitation (ADR-0001 D8a). One representative
    # registration per training, newest first.
    @organization_inactive_training_registrations = inactive_only_training_registrations
  end

  def set_index_variables
    @sector_options = Sector.published.excluding_other.order(:name).pluck(:name, :id)
    @age_group_options = Category.age_ranges.published.ordered_by_position_and_name.map { |category| [ category.decorate.age_group_label, category.id ] }
  end

  def populations_served
    authorize! @organization
    @sort = params[:sort].presence_in(Organization::BREAKDOWN_SORTS) || Organization::BREAKDOWN_SORTS.first
  end

  private

  def published_section_records(section, page:)
    records = case section
    when "workshops"
      openly_credited(authorized_scope(@organization.credited_workshops.with_author_credit)).includes(created_by: :person)
    when "stories"
      authorized_scope(@organization.stories.with_author_credit)
    end
    records.includes(:primary_asset).order(created_at: :desc).paginate(page: page, per_page: 8)
  end

  # Non-admins don't see workshops credited anonymously — listing them here would
  # tie an anonymous author to this organization.
  def openly_credited(workshops)
    return workshops if allowed_to?(:manage?, Organization)

    anonymous_people = Person.where(anonymous_contributions: true).select(:id)
    workshops = workshops.credited_openly
    workshops.where.not(author_id: anonymous_people)
             .or(workshops.where(author_id: nil).where.not(created_by_id: User.where(person_id: anonymous_people).select(:id)))
  end

  def set_organization
    @organization = Organization.includes(
      :organization_status, :windows_type, :addresses, :contact_methods,
      :categorizable_items,
      { comments: [ :created_by, :updated_by ] },
      affiliations: { person: [ :user, :affiliations, *Organization::PEOPLE_TAGGINGS ] }
    ).find(params[:id])
  end

  # Strong parameters
  def organization_params
    params.require(:organization).permit(
      :name, :description, :start_date, :end_date, :mission_vision_values,
      :organization_type, :organization_type_other, :school, :filemaker_code, :logo, :notes, :email, :website_url,
      :organization_status_id, :location_id, :windows_type_id, :high_profile, :parent_id,
      :tax_id,
      :profile_show_sectors, :profile_show_age_ranges, :profile_show_email, :profile_show_phone,
      :profile_show_website, :profile_show_description, :profile_show_workshops,
      :profile_show_stories, :profile_show_events_registered, :profile_show_workshop_logs,
      affiliations_attributes: [
        :id,
        :person_id,
        :inactive,
        :inactive_supplied,
        :primary_contact,
        :title,
        :start_date,
        :end_date,
        :organization_address_id,
        :_destroy
      ],
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      notifications_attributes: Notification::PERMITTED_LOG_ATTRIBUTES,
      contact_methods_attributes: [ :id, :kind, :contact_type, :value, :primary, :inactive, :_destroy ],
      addresses_attributes: [
        :id,
        :address_type,
        :primary,
        :inactive,
        :invoice_address,
        :phone,
        :street_address,
        :city,
        :state,
        :state_outside_usa,
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

  def dedupe_config
    {
      model_class: Organization,
      domain: :organizations,
      candidate_finder: -> { OrganizationServices::DuplicateFinder.new.groups },
      editable_columns: %w[
        name filemaker_code email website_url organization_type description
        mission_vision_values notes organization_status_id organization_obligation_id
      ],
      union_columns: %w[filemaker_code],
      merge_keeper: ->(keep, delete) {
        keep.filemaker_code = Organization.join_filemaker_codes(keep.filemaker_code, delete.filemaker_code)
        @keeper_primary_address_signature = AddressDeduper.primary_signature(keep, delete)
        @keeper_primary_contact_signatures = ContactMethodDeduper.primary_signatures(keep, delete)
      },
      after_merge: ->(keep) {
        AddressDeduper.new(keep, primary_signature: @keeper_primary_address_signature).call
        ContactMethodDeduper.new(keep, primary_signatures: @keeper_primary_contact_signatures).call
        AffiliationDeduper.new(keep).call
      },
      belongs_to_options: -> {
        {
          "organization_status_id" => OrganizationStatus.order(:name),
          "organization_obligation_id" => OrganizationObligation.order(:name)
        }
      },
      record_extras: ->(org) {
        [ org.filemaker_code.presence && "FileMaker #{org.filemaker_code}", org.program_location ].compact.join(" · ").presence
      }
    }
  end

  # One inactive registration per training the org never actively attended, newest
  # first — the source for the edit form's red attendance chips (ADR-0001 D8a).
  def inactive_only_training_registrations
    return [] unless @organization.persisted?

    active_event_ids = @organization.event_registrations.active.select(:event_id)
    @organization.event_registrations.inactive
                 .joins(:event)
                 .where(events: { facilitator_training: true })
                 .where.not(event_id: active_event_ids)
                 .includes(:event)
                 .sort_by { |registration| registration.event.start_date || Date.new(1900, 1, 1) }
                 .reverse
                 .uniq(&:event_id)
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
