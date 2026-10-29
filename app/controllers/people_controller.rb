class PeopleController < ApplicationController
  include AhoyTracking, Dedupable
  before_action :set_person, only: %i[ show edit update destroy workshop_logs checkout bio all_comments send_form_link ]

  # The profile's "Submitted content" sections — private to the person and admins,
  # not part of the public profile even after profile viewing opens up.
  PRIVATE_SECTIONS = %w[ workshop_ideas story_ideas workshop_variation_ideas workshop_logs monthly_reports ].freeze
  SECTION_SHARE_FLAGS = {
    "affiliations" => :profile_show_affiliations,
    "workshops" => :profile_show_workshops,
    "workshop_variations" => :profile_show_workshop_variations,
    "stories" => :profile_show_stories,
    "resources" => :profile_show_resources,
    "events" => :profile_show_events_registered
  }.freeze

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(Person.includes(
        { avatar_attachment: :blob },
        :user,
        sectorable_items: :sector,
        affiliations: :organization,
        event_registrations: :event,
        categorizable_items: { category: :category_type }
      ))
      filters = authorized_scope(params, as: :index).to_unsafe_h
      name_email = filters.delete(:name_email)
      contact_info = filters.delete(:contact_info)
      work_location = filters.delete(:work_location)
      filtered = base_scope.search_by_params(filters)
      filtered = filtered.search_name_email(name_email)
      filtered = filtered.search_contact(contact_info)
      filtered = filtered.distinct if contact_info.present?
      filtered = located_by_work_location(filtered, work_location) if work_location.present?
      filtered = filtered.order(:first_name, :last_name)

      total = filtered.count
      @count_display = count_display(total)
      @people = filtered.paginate(page: params[:page], per_page: per_page, total_entries: total)

      render :people_results
    else
      render :index
    end
  end

  def email_addresses
    authorize! Person, to: :manage?
    filters = params.to_unsafe_h
    name_email = filters.delete(:name_email)
    contact_info = filters.delete(:contact_info)
    work_location = filters.delete(:work_location)
    people = Person.includes(:user).search_by_params(filters)
    people = people.search_name_email(name_email)
    people = people.search_contact(contact_info)
    people = people.distinct if contact_info.present?
    people = located_by_work_location(people, work_location) if work_location.present?
    @email_addresses = people.filter_map { |person| person.preferred_email.presence }.uniq.sort
  end

  def show
    authorize! @person
    @person = Person.includes(:avatar_attachment, :contact_methods, :user,
                              categorizable_items: { category: :category_type }).find(params[:id]).decorate
    track_view(@person)
    @pending_change_requests = own_pending_change_requests unless turbo_frame_request?

    set_checkout_flash
    set_membership

    # Handle paginated sections for Turbo Frame requests
    if turbo_frame_request?
      per_page = params[:section] == "stories" ? 8 : 9
      section = params[:section]

      # Re-authorize the private sections, and any section the person hid from
      # public view, on the narrow owner/admin rule, so a crafted ?section= frame
      # request can't reach them once show? lets non-owners view the profile.
      share_flag = SECTION_SHARE_FLAGS[section]
      authorize! @person, to: :own_record? if PRIVATE_SECTIONS.include?(section) || (share_flag && !@person.public_send(share_flag))

      case section
      when "workshops"
        # Credit the person for workshops they authored, or — the legacy fallback —
        # that their user account created (AuthorCreditable#author_person).
        @workshops = visible_authored_content(Workshop.credited_to_person(@person)).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/workshops", locals: { person: @person, workshops: @workshops }
      when "workshop_variations"
        # Author, or the legacy fallback to their user's creations (author_person).
        @workshop_variations = visible_authored_content(WorkshopVariation.credited_to_person(@person)).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/workshop_variations", locals: { person: @person, workshop_variations: @workshop_variations }
      when "stories"
        @stories = authorized_scope(Story.with_author_credit, as: :on_profile, scope_options: { person: @person })
                     .order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/stories", locals: { person: @person, stories: @stories }
      when "resources"
        # Author, or the legacy fallback to their user's creations (author_person).
        @resources = visible_authored_content(Resource.credited_to_person(@person)).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/resources", locals: { person: @person, resources: @resources }
      when "events"
        # Admins and the profile's own person also see reconciled-away registrations
        # (cancelled, no-show, transferred-out), flagged with their status; everyone
        # else sees only active ones.
        registrations = @person.event_registrations.includes(:event).order("events.start_date DESC").references(:events)
        registrations = registrations.active unless allowed_to?(:own_record?, @person)
        @event_registrations = registrations.paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/events", locals: { person: @person, event_registrations: @event_registrations }
      when "workshop_ideas"
        # Author, or the legacy fallback to their user's creations (author_person).
        @workshop_ideas = WorkshopIdea.credited_to_person(@person).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/workshop_ideas", locals: { person: @person, workshop_ideas: @workshop_ideas }
      when "story_ideas"
        @story_ideas = StoryIdea.credited_to_person(@person).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/story_ideas", locals: { person: @person, story_ideas: @story_ideas }
      when "workshop_logs"
        @workshop_logs = WorkshopLog.credited_to_person(@person).includes(:workshop, :windows_type, :quotable_item_quotes, :gallery_assets).order(workshop_held_on: :desc, created_at: :desc)
        render partial: "people/sections/workshop_logs", locals: { person: @person, workshop_logs: @workshop_logs }
      when "monthly_reports"
        @monthly_reports = MonthlyReport.credited_to_person(@person).order(Arel.sql("COALESCE(reports.date, reports.created_at) DESC")).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/monthly_reports", locals: { person: @person, monthly_reports: @monthly_reports }
      when "workshop_variation_ideas"
        @workshop_variation_ideas = WorkshopVariationIdea.credited_to_person(@person).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/workshop_variation_ideas", locals: { person: @person, workshop_variation_ideas: @workshop_variation_ideas }
      when "affiliations"
        @affiliations = @person.affiliations.active_or_pending.includes(organization: :logo_attachment).paginate(page: params[:page], per_page: per_page)
        render partial: "people/sections/affiliations", locals: { person: @person, affiliations: @affiliations }
      end
    end
  end

  # Every comment connected to this person — their profile plus the records that
  # hang off them (registrations, scholarships, CE registrations, user account) —
  # in one newest-first feed you can add to and edit in place. Staff-only, since
  # comments are internal notes (CommentPolicy#manage? = admin).
  def all_comments
    authorize! @person, to: :manage?, with: CommentPolicy
    @person = @person.decorate

    base = PersonCommentAggregator.new(@person).comments
    @comment_targets = helpers.person_record_targets(@person)

    if turbo_frame_request?
      filtered = base.search_by_params(params)
      @total_count = base.count
      @count_display = count_display(filtered.count, @total_count)
      @comments = filtered.paginate(page: params[:page], per_page: 20)
      FeedRecordPreloader.new(@comments).call
      render :person_comments_results
    else
      @total_count = base.count
      @flagged_count = base.flagged.count
      @new_comment = Comment.new
      @deleted_comments = Analytics::PersonActivityEvents.new(@person.object).deleted_comment_events.map(&:decorate)
      track_view("person_all_comments", { person_id: @person.id })
    end
  end

  def workshop_logs
    authorize! @person
    @person = @person.decorate
    all_logs = WorkshopLog.credited_to_person(@person).includes(:workshop, :windows_type, :quotable_item_quotes, :gallery_assets).order(workshop_held_on: :desc, created_at: :desc)
    @grouped_logs = all_logs.group_by { |log| log.workshop_id || log.external_workshop_title }.sort_by { |_key, logs|
      dates = logs.first(10).map { |l| -(l.workshop_held_on || l.created_at.to_date).to_time.to_i }
      dates.fill(0, dates.size...10)
    }.to_h

    if params[:workshop_id].present?
      @filtered_logs = all_logs.select { |log| log.workshop_id == params[:workshop_id].to_i }
    elsif params[:external_title].present?
      @filtered_logs = all_logs.select { |log| log.external_workshop_title == params[:external_title] }
    end
  end

  # Read-only profile bio for the event-staff editor, fetched when a person is
  # picked for a new staff row. Returns sanitized HTML so the client can render
  # it directly. Person search is admin-gated, so show? (admin or owner) is the
  # right authorization here.
  def bio
    authorize! @person, to: :show?
    has_bio = @person.profile_show_bio? && @person.bio.present?
    render json: {
      show_bio: @person.profile_show_bio?,
      has_bio: has_bio,
      bio_html: (helpers.sanitize(@person.bio, tags: %w[p br strong em a ul ol li b i], attributes: %w[href]) if has_bio),
      edit_path: (edit_person_path(@person) if allowed_to?(:edit?, @person))
    }
  end

  def checkout
    authorize! @person, with: PersonPolicy

    amount = params[:amount].to_i
    amount = (amount * 100).to_i # Convert dollars to cents
    amount = 1000 if amount < 1000 # Minimum $10.00
    metadata = stripe_metadata(person_id: @person.id)

    @checkout_session = @person.payment_processor.checkout(
      mode: "payment",
      metadata: metadata,
      payment_intent_data: {
        metadata: metadata
      },
      line_items: [ {
        price_data: {
          currency: "usd",
          product_data: {
            name: "Donation to #{Setting.app_organization_name}"
          },
          unit_amount: amount
        },
        quantity: 1
      } ],
      success_url: person_url(@person, checkout: "success"),
      cancel_url: person_url(@person, checkout: "cancelled")
    )

    redirect_to @checkout_session.url, allow_other_host: true, status: :see_other
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
      { professional_licenses: { continuing_education_registrations: { event_registration: :event } } },
      affiliations: { organization: [ :logo_attachment, :addresses ] }
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
      @duplicates = find_duplicate_people(
        @person.first_name,
        @person.last_name,
        @person.email,
        legal_first_name: @person.legal_first_name,
        email_2: @person.email_2
      )
      if @duplicates.any?
        @first_name = @person.first_name
        @last_name = @person.last_name
        @email = @person.email
        @legal_first_name = @person.legal_first_name
        @email_2 = @person.email_2
        @blocked = @duplicates.any? { |d| d[:blocked] }
        set_form_variables
        respond_to do |format|
          format.html { render :new, status: :unprocessable_content }
          format.turbo_stream
        end
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

    attrs = person_params
    reject_locked_license_changes!(attrs)
    @person.assign_attributes(attrs)

    if @person.save
      redirect_to person_update_return_path, notice: "Person was successfully updated."
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

  # Email this person the public link to one of the agreement scenario forms
  # (Form.agreement_forms), recording the send so staff can see who was contacted for
  # which scenario. The notification stores what was sent: the form name in
  # custom_subject and the public form URL in custom_message. `agreement_links`
  # reopens the collapsed panel on the way back.
  def send_form_link
    authorize! @person

    # Either an agreement form's public link, or an upcoming facilitator
    # training's public registration form (the panel's nested event rows).
    if params[:event_id].present?
      event = Event.where(published: true).facilitator_trainings.find(params[:event_id])
      link_name = "#{event.decorate.title_with_month_year} registration"
      link_url = new_event_public_registration_url(event)
    else
      form = Form.agreement_forms.find(params[:form_id])
      link_name = form.display_name
      link_url = public_form_url(form.slug)
    end

    email = @person.preferred_email
    if email.blank?
      redirect_to edit_person_path(@person, agreement_links: 1, anchor: "agreement-links"), alert: "#{helpers.person_name(@person)} has no email address on file."
      return
    end

    NotificationServices::CreateNotification.call(
      noticeable: @person,
      person: @person,
      kind: :form_link_request,
      recipient_role: :person,
      recipient_email: email,
      notification_type: 0,
      custom_subject: link_name,
      custom_message: link_url,
      sender: current_user
    )

    redirect_to edit_person_path(@person, agreement_links: 1, anchor: "agreement-links"), notice: "Sent the #{link_name} link to #{email}."
  end

  def check_duplicates
    authorize!

    @first_name = params[:first_name]
    @last_name = params[:last_name]
    @email = params[:email]
    @legal_first_name = params[:legal_first_name]
    @email_2 = params[:email_2]
    @duplicates = find_duplicate_people(
      @first_name, @last_name, @email,
      legal_first_name: @legal_first_name, email_2: @email_2
    )
    @blocked = @duplicates.any? { |d| d[:blocked] }
  end

  private

  def located_by_work_location(people, query)
    filters = PersonLocations.filters_from(**PersonLocations.parse_query(query))
    return people.none if filters.nil?
    people.where(id: PersonLocations.new(people.select(:id)).matching(**filters).map(&:registrant_id))
  end

  def dedupe_config
    {
      model_class: Person,
      domain: :people,
      candidate_finder: -> { PersonServices::DuplicateFinder.new.groups },
      # Carry the deleted person's avatar onto the keeper when the keeper has none;
      # otherwise it's purged with the deleted person (has_one_attached dependent: :purge).
      movable_attachments: %w[avatar],
      editable_columns: %w[
        first_name legal_first_name last_name email email_type email_2 email_2_type
        date_of_birth pronouns filemaker_code member_since notes
      ],
      union_columns: %w[filemaker_code],
      field_logins: ->(person) { logins_by_email_field(person) },
      merge_outcomes: ->(keep, delete) { email_merge_outcomes(keep, delete) },
      # Merging two people who each have a login leaves the kept person with both
      # (users.person_id has no unique constraint); both logins still sign in to the
      # one record. Surface it so the admin isn't surprised — it doesn't block.
      merge_notes: ->(keep, delete) {
        [ dropped_email_note(keep, delete), login_merge_note(keep, delete) ].compact
      },
      # Before the merge moves the deleted person's taggings onto the keeper (where
      # they become indistinguishable), capture which primary sector + age range to
      # keep: the survivor's own, or — when it has none — the deleted person's.
      merge_keeper: ->(keep, delete) {
        keep.filemaker_code = Person.join_filemaker_codes(keep.filemaker_code, delete.filemaker_code)
        @keeper_primary_sector_id = keep.sectorable_items.find_by(is_primary: true)&.sector_id ||
          delete.sectorable_items.find_by(is_primary: true)&.sector_id
        @keeper_primary_age_category_id = keep.age_range_categorizable_items.find_by(is_primary: true)&.category_id ||
          delete.age_range_categorizable_items.find_by(is_primary: true)&.category_id
        @keeper_default_pay_customer_id = keep.pay_customers.active.find_by(default: true)&.id
        @keeper_primary_address_signature = AddressDeduper.primary_signature(keep, delete)
        @keeper_primary_contact_signatures = ContactMethodDeduper.primary_signatures(keep, delete)
        @primary_login_id = primary_login(keep, delete)&.id
      },
      # Reconcile what the generic merge leaves inconsistent on the kept person:
      #   * redundant professional licenses within a kind (merge blank-number
      #     placeholders into a real license — done first so any CE it moves is then
      #     collapsed by the CE deduper below);
      #   * duplicate CE registrations for one event (collapse them, preserving the
      #     loser's payments, so the person isn't billed twice for a single enrollment);
      #   * two "primary" sectors / age ranges (keep the survivor's, demote the rest,
      #     leaving the single primary Person's single-primary validations require);
      #   * two live Pay customers (keep the survivor's own default, else the newest,
      #     and soft-delete the redundant sibling so `payment_processor` isn't
      #     ambiguous and a later checkout can't flip it);
      #   * duplicate addresses / contact methods (merge identical ones into one,
      #     keeping a single primary — the survivor's own, else the deleted person's);
      #   * identical affiliations (same org, title, dates, and status → one);
      #   * a survivor gaining a login (adopt the primary login's email as primary).
      after_merge: ->(keep) {
        PersonServices::ReconcileProfessionalLicenses.new(keep).call
        ContinuingEducationDeduper.new(ContinuingEducationRegistration.for_registrant(keep.id).to_a).call
        PersonServices::ReconcilePrimaryDesignations.new(keep,
          primary_sector_id: @keeper_primary_sector_id,
          primary_age_category_id: @keeper_primary_age_category_id).call
        PersonServices::ReconcileDefaultPayCustomer.new(keep,
          preferred_customer_id: @keeper_default_pay_customer_id).call
        AddressDeduper.new(keep,
          primary_signature: @keeper_primary_address_signature).call
        ContactMethodDeduper.new(keep,
          primary_signatures: @keeper_primary_contact_signatures).call
        AffiliationDeduper.new(keep).call
        sync_primary_login_email(keep)
      },
      record_partial: "people/dedupe_record"
    }
  end

  # The primary login's email becomes the keeper's primary, so it isn't dropped.
  def dropped_email_note(keep, delete)
    held = [ keep.email, keep.email_2, primary_login(keep, delete)&.email ].compact_blank
    dropped = [ delete.email, delete.email_2 ].compact_blank
      .reject { |address| PlaceholderEmail.match?(address) || held.any? { |kept| kept.casecmp?(address) } }
      .uniq(&:downcase)
    return if dropped.empty?

    "#{dropped.to_sentence} #{dropped.one? ? "isn't" : "aren't"} on the kept person and will be dropped. To keep #{dropped.one? ? "it" : "one"}, enter it in Email 2 on the right."
  end

  def logins_by_email_field(person)
    logins = User.where(person_id: person.id).index_by { |user| user.email.downcase }
    %w[email email_2].each_with_object({}) do |column, by_field|
      login = logins[person.public_send(column).to_s.downcase]
      by_field[column] = login if login
    end
  end

  # What the login email sync changes on the kept person, flagged beside each email and login.
  def email_merge_outcomes(keep, delete)
    login = primary_login(keep, delete)
    return {} if login.nil? || login.email.casecmp?(keep.email.to_s)

    fields = { "email" => { keep: "becomes #{login.email} (#{primary_login_reason(login, keep, delete)})" } }
    if keep.email.present?
      secondary_free = keep.email_2.blank? || keep.email_2.casecmp?(login.email)
      fields["email_2"] = { keep: secondary_free ? "becomes #{keep.email}" : "stays; #{keep.email} is saved in a comment" }
    end
    delete_column = %w[email email_2].find { |column| delete.public_send(column).to_s.casecmp?(login.email) }
    fields[delete_column] = { **fields[delete_column].to_h, delete: "becomes the primary email" } if delete_column

    { fields: fields, records: { login => "its email becomes the primary email" } }
  end

  def login_merge_note(keep, delete)
    return unless delete.user

    login = primary_login(keep, delete)
    return "#{keep.full_name} takes over the other person's login, so its email (#{login.email}) becomes their primary email. The email chosen here moves to their secondary email." unless keep.user

    both = "Both people have a login. After the merge, both logins sign in to the kept person (#{keep.full_name}) — no login is lost. Their profile shows whichever login was used most recently."
    return both if login.email.casecmp?(keep.email.to_s)

    "#{both} Their primary email becomes #{login.email}, #{primary_login_reason(login, keep, delete)}. The email chosen here moves to their secondary email."
  end

  # The login whose email the kept person's primary email follows: an adopted login,
  # else the most recently used of both; ties go to the only person with history, else the kept person.
  def primary_login(keep, delete)
    @primary_logins ||= Hash.new do |memo, (kept, deleted)|
      memo[[ kept, deleted ]] = find_primary_login(kept, deleted)
    end
    @primary_logins[[ keep, delete ]]
  end

  def find_primary_login(keep, delete)
    return unless delete.user
    return delete.user unless keep.user

    favored_person_id = person_with_history(keep, delete)&.id || keep.id
    User.where(person_id: [ keep.id, delete.id ]).max_by do |login|
      [ login.last_sign_in_at.to_i, login.person_id == favored_person_id ? 1 : 0 ]
    end
  end

  def primary_login_reason(login, keep, delete)
    return "the login they take over" unless keep.user
    return "the login used most recently" if login.last_sign_in_at
    return "the login of the person with affiliations or event registrations" if person_with_history(keep, delete)

    "the kept person's login"
  end

  def person_with_history(keep, delete)
    @people_with_history ||= Hash.new do |memo, pair|
      with_history = pair.select { |person| person.affiliations.exists? || person.event_registrations.exists? }
      memo[pair] = (with_history.first if with_history.one?)
    end
    @people_with_history[[ keep, delete ]]
  end

  # Saves the preview's edits first so the sync moves the email the admin picked into
  # the secondary slot.
  def sync_primary_login_email(keep)
    login = User.find_by(id: @primary_login_id)
    return unless login

    keep.save! if keep.changed?
    PersonLoginEmailSync.call(login)
  end

  # Showing anonymous content to anyone but the person and admins would tie an
  # "Anonymous" credit back to a name.
  def visible_authored_content(scope)
    return scope if allowed_to?(:own_record?, @person)
    return scope.none if @person.anonymous_contributions?
    scope.credited_openly
  end

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
                        [ affiliation.active? ? 0 : 1,
                          affiliation.organization&.name.to_s.downcase ]
                      }
      @person.affiliations.proxy_association.target.replace(sorted)
    end
    @person.affiliations.build if @person.affiliations.empty?

    # "Other" is the free-text catch-all, not a real tag (see Sector), so it's
    # never offered in the sector picker — a typed "Other" is captured as an
    # OtherResponse, not saved as the literal "Other" sector.
    @all_sectors = Sector.published.excluding_other.order(:name)
    @sectors_collection = @all_sectors.pluck(:name, :id)
    @current_sector_ids = @person.sectorable_items.map(&:sector_id)

    # Age ranges edit as a sectors-style cocoon chip picker, tagged via
    # age_range_categorizable_items nested attributes.
    @age_range_type = CategoryType.find_by(name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE)
    age_ranges = @age_range_type ? @age_range_type.categories.published.order(:position, :name) : Category.none
    @age_ranges_collection = age_ranges.pluck(:name, :id)
    @current_age_range_category_ids = @person.age_range_categorizable_items.map(&:category_id)

    @staff_tags_collection = StaffTag.published.ordered.pluck(:name, :id)
    @current_staff_tag_ids = @person.staff_tag_ids
  end

  def find_duplicate_people(first_name, last_name, email, legal_first_name: nil, email_2: nil)
    duplicates = []
    duplicate_ids = Set.new

    # Entered emails (primary + secondary) drive both email matching and match
    # classification. Placeholder-domain addresses are seed data, so they're
    # excluded from the DB lookup.
    entered_emails = [ email, email_2 ].filter_map { |e| e.presence&.downcase }.uniq
    query_emails = entered_emails.reject { |e| PlaceholderEmail.domain_address?(e) }

    # Entered first-name forms: the first name and legal first name, normalized.
    # Normalize removes periods and extra whitespace: "J. R." -> "jr".
    entered_first_forms = [ first_name, legal_first_name ].filter_map { |n| NicknameMap.normalize(n).presence }.uniq
    normalized_last = NicknameMap.normalize(last_name)

    # Check for name matches (exact + nickname variants), comparing both the
    # entered first name and legal first name (and their nickname variants)
    # against the stored first name and legal first name.
    if first_name.presence && last_name.presence
      first_variants = NicknameMap.variants_for(first_name)
      first_variants += NicknameMap.variants_for(legal_first_name) if legal_first_name.present?
      first_variants = first_variants.uniq

      name_matches = Person.includes(:user)
                           .where("REPLACE(REPLACE(LOWER(last_name), '.', ''), ' ', '') = ?", normalized_last)
                           .where(
                             "REPLACE(REPLACE(LOWER(first_name), '.', ''), ' ', '') IN (:variants) OR " \
                             "REPLACE(REPLACE(LOWER(legal_first_name), '.', ''), ' ', '') IN (:variants)",
                             variants: first_variants
                           )
                           .limit(10)

      name_matches.each do |person|
        next if duplicate_ids.include?(person.id)

        duplicate_ids.add(person.id)
        exact_name = exact_first_name_match?(entered_first_forms, person)
        duplicates << format_duplicate(person, exact: exact_name, entered_email: email, entered_emails: entered_emails)
      end
    end

    # Check for email matches on the primary or secondary entered email.
    # Only match person.email when person has no user (otherwise it's a stale copy of user.email)
    if query_emails.any? && duplicates.size < 10
      email_query = Person.includes(:user)
                          .left_joins(:user)
                          .where(
                            "(users.id IS NULL AND LOWER(people.email) IN (:emails)) OR " \
                            "LOWER(people.email_2) IN (:emails) OR LOWER(users.email) IN (:emails)",
                            emails: query_emails
                          )
                          .limit(10)

      email_query.each do |person|
        next if duplicate_ids.include?(person.id)

        duplicate_ids.add(person.id)
        exact_name = last_name.present? &&
          NicknameMap.normalize(person.last_name) == normalized_last &&
          exact_first_name_match?(entered_first_forms, person)
        duplicates << format_duplicate(person, exact: exact_name, entered_email: email, entered_emails: entered_emails)
        break if duplicates.size >= 10
      end
    end

    sort_order = { "exact" => 0, "name" => 1, "approximate" => 2, "email" => 3, "nickname" => 4 }
    duplicates.sort_by { |d| [ d[:blocked] ? -1 : 0, sort_order[d[:match_type]] || 4 ] }
  end

  # True when any entered first-name form (first or legal, normalized) matches
  # the stored person's first name or legal first name directly — a real name
  # match rather than only a nickname bridge.
  def exact_first_name_match?(entered_first_forms, person)
    stored_forms = [ person.first_name, person.legal_first_name ].filter_map { |n| NicknameMap.normalize(n).presence }
    (entered_first_forms & stored_forms).any?
  end

  def format_duplicate(person, exact: true, entered_email: nil, entered_emails: nil)
    entered_emails = (Array(entered_emails).presence || [ entered_email ]).filter_map { |e| e.presence&.downcase }.uniq

    labeled_emails = []
    # Skip person.email when person has a user (it's a stale copy of user.email)
    labeled_emails << { label: "Email", value: person.email } if person.email.present? && person.user.blank?
    labeled_emails << { label: "Secondary email", value: person.email_2 } if person.email_2.present?
    labeled_emails << { label: "User email", value: person.user.email } if person.user&.email.present?
    emails = labeled_emails.map { |e| e[:value] }.uniq
    any_email_match = emails.any? { |e| entered_emails.include?(e.downcase) }
    primary_email_match = exact && entered_email.present? &&
      person.email.present? && person.email.downcase == entered_email.downcase
    secondary_email_match = exact && any_email_match && !primary_email_match

    # Exact name + primary email is an "exact" match and blocks creation. Exact
    # name plus a secondary or user email is "approximate" — the admin is warned
    # but can still create the person (they may legitimately share an email).
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

  # Where to send the admin after a successful update. Defaults to the person's
  # profile, but returns to Data health or the registration org-linking page when
  # the edit was opened from there (preserving that page's own return_to).
  def person_update_return_path
    if params[:return_to] == "data_health"
      helpers.data_health_return_path(params[:check])
    elsif params[:return_to] == "dedupe"
      dedupe_index_people_path(anchor: "dedupe-record-#{@person.id}")
    elsif params[:return_to] == "registration_link" && params[:event_registration_id].present?
      link_organization_event_registration_path(params[:event_registration_id], return_to: params[:link_org_return_to].presence)
    else
      @person
    end
  end

  # Only allow a list of trusted parameters through.
  # Server-side backstop for the per-license edit gating (ProfessionalLicensePolicy):
  # drop any submitted change to a license the current user isn't allowed to edit or
  # destroy — i.e. a CE-tied license edited by a non-admin owner. The view already
  # renders those read-only; this stops a crafted request from slipping past. Admins
  # are allowed everything, so it's a no-op for them (and thus for the admin-only form
  # today). New licenses (no id) have no CE registrations yet, so they pass through.
  def reject_locked_license_changes!(attrs)
    license_attrs = attrs[:professional_licenses_attributes]
    return if license_attrs.blank?

    license_attrs.keys.each do |key|
      license = license_attrs[key]
      id = license[:id]
      next if id.blank?

      record = @person.professional_licenses.find_by(id: id)
      next unless record

      destroying = license[:_destroy].to_s.in?(%w[ 1 true ])
      rule = destroying ? :destroy? : :update?
      license_attrs.delete(key) unless allowed_to?(rule, record)
    end
  end

  # Permit + admin-only filtering lives in PersonPolicy's params_filter, so a
  # non-admin owner's submission is stripped to the fields they may change.
  def person_params
    authorized(params.require(:person))
  end

  def set_membership
    return unless Membership.enabled? && allowed_to?(:own_record?, @person)

    @membership = @person.current_membership&.decorate
    return unless @membership

    @membership_invoices = @membership.object.membership_invoices
      .not_paid_in_full
      .includes(:allocations)
      .order(:start_date)
      .to_a
    @membership_autopay = @membership.autopay_on?
    @membership_has_card = @person.payment_processor&.payment_methods&.exists? || false
  end

  def set_checkout_flash
    if params[:checkout] == "success"
      flash[:notice] = "Thank you for your donation!"
    elsif params[:checkout] == "cancelled"
      flash[:alert] = "Donation was cancelled."
    elsif params[:membership_invoice_checkout] == "success"
      flash[:notice] = "Thank you! Your membership payment was received."
    elsif params[:membership_invoice_checkout] == "cancelled"
      flash[:alert] = "Payment was cancelled."
    elsif params[:autopay_setup] == "success"
      membership = Membership.find_by(id: session.delete(:autopay_setup_membership_id))
      if membership && membership.person == @person.object && allowed_to?(:enable_autopay?, membership)
        membership.update!(autopay_on: true)
        flash[:notice] = "Automatic payments are on."
      end
    elsif params[:autopay_setup] == "cancelled"
      had_setup = session.delete(:autopay_setup_membership_id).present?
      flash[:alert] = "Card setup was cancelled." if had_setup
    end
  end

  def own_pending_change_requests
    return [] unless allowed_to?(:edit_own_profile?, @person)

    @person.profile_change_requests.pending.newest_first.includes(affiliation: :organization).decorate.to_a
  end
end
