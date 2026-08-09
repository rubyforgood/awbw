class EventsController < ApplicationController
  include AhoyTracking, TagAssignable
  skip_before_action :authenticate_user!, only: [ :index, :show, :staff ]
  skip_before_action :verify_authenticity_token, only: [ :preview ]
  before_action :set_event, only: %i[ show edit update destroy preview dashboard sample_ticket registrants roster onboarding staff edit_staff update_staff recipients preview_reminder confirm_reminder send_reminder copy_registration_form feature_recipient_shoutout ]
  before_action :set_report_filters, only: %i[ revenue participation reports scholarships ]
  # The cross-event report suite is visible to admins and event owners alike; what
  # differs is the rows, which EventPolicy's :reportable scope narrows to the
  # viewer's own events.
  before_action :authorize_report!, only: %i[ revenue participation reports scholarships attendees ]
  # Log a visit to each event page / report. after_action so it only fires once
  # the action rendered successfully (authorization inside the actions has passed);
  # the turbo_frame_request? / redirect guards skip the lazy results/charts
  # sub-requests and the confirm-reminder bounce-back. send_reminder is logged
  # inline on a successful send (it always redirects).
  after_action :track_page_view, only: %i[ dashboard roster registrants recipients staff onboarding edit preview sample_ticket revenue participation reports scholarships attendees confirm_reminder ]

  def index
    authorize!
    base_scope = authorized_scope(Event.all)
    events = base_scope.search_by_params(params).order(start_date: :desc)
    # Admins see every event, including unpublished drafts and long-past ones;
    # collapse those into a compact archive list so the cards grid stays focused
    # on current events. Non-admins never receive those events, so they keep
    # every card.
    if allowed_to?(:new?, Event)
      @events, @archived_events = events.partition(&:shown_as_card?)
    else
      @events = events
      @archived_events = []
    end
  end

  def show
    authorize! @event
    @event = @event.decorate
    track_view(@event)
  end

  # Cross-event revenue report over paid events, grouped by year. Shares the
  # event-type + time-period filters with the participation report, and leads the
  # KPI strip with the year of the event navigated from (when arriving from a
  # dashboard), otherwise the current year.
  def revenue
    events, selected_year = filtered_report_events(Event.paid)
    @report = EventRevenueReport.new(events, featured_year: selected_year || @filter_event&.start_date&.year)
  end

  # Cross-event participation report: how many people completed each training,
  # grouped by year. Scopes to all events by default, narrowable to facilitator
  # trainings, and to a single year via the ahoy-style time-period select.
  def participation
    events, selected_year = filtered_report_events(Event.all)
    @report = EventParticipationReport.new(events, featured_year: selected_year)
  end

  # Reports hub: the revenue, participation and scholarship report summaries side
  # by side, each linking to its full report. Pre-filterable to a single event via
  # event_id (the per-event "Reports" tab links here scoped to its event).
  def reports
    @period = params[:period].presence_in(%w[ this_year last_year all_time ]) || "this_year"
    @revenue_report = EventRevenueReport.new(report_events(Event.paid))
    @participation_report = EventParticipationReport.new(report_events(Event.all))
    @scholarship_report = EventScholarshipReport.new(report_events(Event.facilitator_trainings))
  end

  # Cross-event scholarship report: scholarship dollars and award counts (funded
  # vs unfunded) per facilitator training, grouped by year, with an attended-
  # trainee count split into Live vs On-demand. Sibling of the revenue and
  # participation reports.
  def scholarships
    events, selected_year = filtered_report_events(Event.facilitator_trainings)
    @report = EventScholarshipReport.new(events, featured_year: selected_year, funder: @filter_funder)
  end

  # Cross-event index of the people behind event registrations, deduped to one row
  # per person. Lazy-loaded like the people index: the frame request builds the
  # filtered/paginated page and its roster; the full request renders the shell
  # (header, filters, skeleton). The population defaults to people who attended a
  # facilitator training, but attendance outcome and event type are filters — the
  # report KPIs drill in here for no-shows and non-trainings too.
  def attendees
    @attendance_status = attendee_attendance_status
    @attendee_event_type = attendee_event_type
    unless turbo_frame_request?
      set_attendee_filter_options
      return render :attendees
    end

    people = filtered_attendees
    # The charts frame is loaded lazily (only when the user reveals it), so the
    # expensive cross-event breakdowns run solely on that request.
    if turbo_frame_request_id == "attendees_charts"
      @breakdowns = AttendeesBreakdowns.new(people, events: attendee_events, registrations: attendee_registrations)
      return render :attendees_charts
    end

    per_page = params[:number_of_items_per_page].presence || 25
    @count_display = people.count
    @people = people.paginate(page: params[:page], per_page: per_page)
    @roster = AttendeesRoster.new(@people, events: attendee_events, registrations: attendee_registrations)
    render :attendees_results
  end

  def new
    authorize!
    @event = Event.new.decorate
    set_form_variables
  end

  def edit
    authorize! @event
    # Materialize any missing built-in callouts so the editor shows them all
    # (idempotent; heals events created before a built-in existed).
    BuiltinCallouts.seed(@event)
    set_form_variables
  end

  def preview
    authorize! @event
    @event.assign_attributes(event_params)
    @event = @event.decorate
    @preview = true
    render :show
  end

  def dashboard
    authorize! @event
    @event = @event.decorate
    @dashboard = EventDashboard.new(@event)
  end

  # Admin preview of the registration ticket. Builds an in-memory sample
  # registration — never saved. By default it models a typical registrant (no
  # scholarship, no continuing education, no extra requests) so the preview is
  # indicative of what most tickets look like. The "Show all options" toggle
  # (?options=all) turns on every registrant-chosen option at once so admins can
  # see every section present. The ticket partial renders in `preview: true`
  # mode, which disables the state-changing buttons (pay, resend, cancel) and
  # renders the callout cards non-navigating. A sentinel slug lets the callout
  # route helpers build without raising, since the sample isn't persisted.
  def sample_ticket
    authorize! @event, to: :dashboard?

    # Materialize any missing built-in callouts (idempotent, like #edit) so the
    # preview renders purely from the event's materialized rows — the built-ins
    # are real editable rows once seeded, so there's no code-defined fallback to
    # fall back to here.
    BuiltinCallouts.seed(@event)

    @show_all_options = params[:options] == "all"
    # Always an unsaved, data-free sample so the preview can never read from or
    # write to a real registrant. Its behavioral built-in cards link to the
    # admin-only sample callout previews (see Events::CalloutsController), which
    # render the same in-memory sample — nothing is ever persisted.
    @event_registration = SampleTicketRegistration.new(@event, all_options: @show_all_options).registration
  end

  # The event's active-registrant roster (registrant table + demographic charts),
  # over the shared roster/breakdown partials fed by EventDashboard. The charts are
  # loaded lazily into their own Turbo frame so the heavier breakdown queries only
  # run when the admin reveals them (mirrors the attendees index).
  def roster
    authorize! @event, to: :roster?
    @event = @event.decorate
    @dashboard = EventDashboard.new(@event)
    @roster_registrants = filtered_roster_registrants
    render :event_roster_charts if turbo_frame_request_id == "event_roster_charts"
  end

  def registrants
    authorize! @event, to: :registrants?
    @event = @event.decorate
    # contact_methods (phone) and affiliations (org names) are read only by the
    # CSV export, so skip them on the HTML roster to avoid eager-loading data the
    # page never uses (Bullet: AVOID eager loading).
    registrant_includes = [ :user, { avatar_attachment: :blob } ]
    registrant_includes += [ :contact_methods, { affiliations: :organization } ] if request.format.csv?
    scope = @event.event_registrations
      .includes(:comments, :organizations, :allocations, :scholarships, { continuing_education_registrations: [ :professional_license, :allocations ] }, registrant: registrant_includes)
      .joins(:registrant)
    scope = scope.keyword(params[:keyword]) if params[:keyword].present?
    scope = scope.payment_status(params[:payment_status]) if params[:payment_status].present?
    scope = scope.payment_method(params[:payment_method]) if params[:payment_method].present?
    scope = scope.scholarship_status(params[:scholarship]) if params[:scholarship].present?
    scope = scope.funder(params[:funder]) if params[:funder].present?
    scope = scope.ce_status(params[:ce_status]) if params[:ce_status].present?
    scope = scope.comment_status(params[:comment_status]) if params[:comment_status].present?
    scope = scope.comment_text(params[:comment]) if params[:comment].present?
    scope = scope.funder_name(params[:funder_name]) if params[:funder_name].present?
    scope = scope.submission_status(params[:submission_status], @event) if params[:submission_status].present?
    scope = scope.registrant_city(params[:city]) if params[:city].present?
    scope = scope.organization_status(params[:org_status], @event) if params[:org_status].present?
    scope = scope.account_status(params[:account_status]) if params[:account_status].present?
    scope = scope.registrant_ids(params[:registrant_ids]) if params[:registrant_ids].present?
    scope = scope.registrant_state(params[:state]) if params[:state].present?
    scope = scope.registrant_county(params[:county]) if params[:county].present?
    scope = scope.registrant_sector(params[:sector]) if params[:sector].present?

    @active_count = scope.active.count
    @inactive_count = scope.inactive.count

    if params[:attendance_status].present?
      scope = scope.attendance_status(params[:attendance_status])
    else
      @status_filter = params[:status_filter].presence || "active"
      scope = scope.inactive if @status_filter == "inactive"
      scope = scope.active if @status_filter == "active"
    end

    @event_registrations = scope.order(Arel.sql("people.first_name, people.last_name")).to_a
    @dashboard = EventDashboard.new(@event)
    @ce_eligible = @event.ce_eligible?

    @submitted_org_names = submitted_org_names_for(@event_registrations)
    @readiness = @event_registrations.to_h do |registration|
      [ registration.id, EventRegistrationReadiness.new(registration) ]
    end
    if params[:readiness].in?(%w[ not_ready ready certificate_due completed ])
      @event_registrations.select! { |r| @readiness[r.id].status.to_s == params[:readiness] }
    end

    emails = @event_registrations.map { |r| r.registrant.preferred_email&.downcase }.compact
    @duplicate_emails = emails.tally.select { |_, count| count > 1 }.keys.to_set

    respond_to do |format|
      format.html
      format.csv do
        send_data event_registrations_csv_string,
          filename: "event-#{@event.id}-registrations-#{Date.current.iso8601}.csv",
          type: "text/csv",
          disposition: "attachment"
      end
    end
  end

  # Admin onboarding tracker: a per-registrant checklist matrix (system setup,
  # info-sent milestones, attendance days) over derived data (program type,
  # scholarship, payment). Mirrors the registrants roster's filters/active toggle.
  def onboarding
    authorize! @event, to: :registrants?
    @event = @event.decorate
    scope = @event.event_registrations
      # Preload each org's affiliations: the row's program-status badge classifies
      # them via Organization#facilitator_status_on, which filters the loaded
      # association — unloaded, that's a per-org query pulling every affiliation row.
      .includes(:checklist_completions, { organizations: :affiliations }, :allocations, :scholarships, :comments, { continuing_education_registrations: [ :professional_license, :allocations ] }, registrant: [ :user, { affiliations: :organization } ])
      .joins(:registrant)
    scope = scope.keyword(params[:keyword]) if params[:keyword].present?

    @active_count = scope.active.count
    @inactive_count = scope.inactive.count
    @status_filter = params[:status_filter].presence || "active"
    scope = @status_filter == "inactive" ? scope.inactive : scope.active

    @event_registrations = scope.order(Arel.sql("people.first_name, people.last_name")).to_a
    # `scholarships` reaches the grant through the polymorphic `allocations.source`,
    # which Rails can't eager-load with a nested `:grant` (it tries `grant` on every
    # source type, e.g. CashPayment). Preload grants on the loaded scholarships in a
    # second pass so the matrix's scholarship column stays query-free.
    ActiveRecord::Associations::Preloader.new(
      records: @event_registrations.flat_map(&:scholarships),
      associations: :grant
    ).call

    # Column show/hide is server-side: `hide` is a comma-separated list of column
    # toggle keys the admin has hidden, threaded through the filters and tab links.
    @hidden_columns = params[:hide].to_s.split(",").map(&:strip).reject(&:blank?)

    respond_to do |format|
      format.html
      format.csv do
        send_data onboarding_csv_string,
          filename: "event-#{@event.id}-onboarding-#{Date.current.iso8601}.csv",
          type: "text/csv",
          disposition: "attachment"
      end
    end
  end


  def staff
    authorize! @event, to: :staff?
    @event = @event.decorate
    @event_staffs = @event.event_staffs
      .includes(person: [ :sectors, { categorizable_items: { category: :category_type } }, { avatar_attachment: :blob }, { affiliations: :organization } ])
      .ordered_by_name
  end

  def edit_staff
    authorize! @event, to: :edit_staff?
    @event.event_staffs.build if @event.event_staffs.empty?
  end

  def update_staff
    authorize! @event, to: :update_staff?

    if @event.update(event_staff_params)
      redirect_to staff_update_return_path, notice: "Event staff updated."
    else
      render :edit_staff, status: :unprocessable_content
    end
  end

  def recipients
    authorize! @event, to: :recipients?
    @event = @event.decorate
    @dashboard = EventDashboard.new(@event)

    # Charts frame is loaded lazily (only when the admin reveals it), so the
    # breakdowns run solely on that request — and it returns before the cards'
    # profile-preloading applicant list, which that frame never renders.
    # Scoped to this event's scholarship recipients via the shared cross-event
    # AttendeesBreakdowns.
    if turbo_frame_request_id == "recipients_charts"
      recipients = Person.where(id: @dashboard.scholarship_applicant_ids)
      @breakdowns = AttendeesBreakdowns.new(recipients,
        events: Event.where(id: @event.id),
        registrations: EventRegistration.active)
      return render :recipients_charts
    end

    @recipient_applicants = filtered_recipient_applicants
  end

  # From the recipients page "Add shoutout" control: flag the chosen registrant
  # for the recipients-page shout-out, seed the shout-out text from their profile
  # bio when it's blank, then send the admin to their registration edit form to
  # review (the toggle and any seeded text are already saved on arrival).
  def feature_recipient_shoutout
    authorize! @event, to: :recipients?
    registration = @event.event_registrations.active.find_by(id: params[:registration_id])
    unless registration
      redirect_to recipients_event_path(@event), alert: "Choose a recipient to feature." and return
    end

    authorize! registration, to: :update?
    registrant = registration.registrant
    registration.update!(shoutout: true)
    if registrant.shoutout_text.blank? && (bio = shoutout_bio_from_profile(registrant))
      registrant.update!(shoutout_text: bio)
    end
    redirect_to edit_event_registration_path(registration, return_to: "recipients", anchor: "shout-out"),
                notice: "Featured on the recipients page — review their shout-out text below.", status: :see_other
  end

  def preview_reminder
    authorize! @event
    @event = @event.decorate
    @ce_eligible = @event.ce_eligible?
    @event_registrations = @event.event_registrations
      .includes(
        :event, :organizations, :comments,
        { scholarships: { grant: :funder } },
        registrant: [ :user, :contact_methods, :addresses ]
      )
      .joins(:registrant)
      .select { |r| r.registrant.preferred_email.present? }

    # Filters keep every registrant in the list and only flag who still matches,
    # so the recipient checkboxes pre-check the matched set rather than removing
    # rows. See app/views/events/_reminder_recipients.html.erb. The dropdown
    # filters reuse the registrants-roster scopes (via the event), so both pages
    # stay in sync; @dashboard supplies the state/county options.
    @dashboard = EventDashboard.new(@event)
    recipient_filter = ReminderRecipientFilter.new(@event_registrations, params, event: @event)
    @matched_ids = recipient_filter.matched_ids
    @filtering = recipient_filter.filtering?

    return render partial: "events/reminder_recipients" if turbo_frame_request?

    @sample_registration = @event_registrations.first
    days_until_event = @event.start_date.present? ? (@event.start_date.to_date - Date.current).to_i : nil
    # Pre-fill the editable message with the standard reminder sentence (days
    # resolved now). Absent param = first load → default; a present-but-blank
    # param = the admin cleared it (e.g. bounced back here) → respect the blank.
    @custom_message = params.key?(:custom_message) ? params[:custom_message].to_s : helpers.default_reminder_message(days_until_event)
    # Pre-fill the editable subject with the standard portal subject. Same
    # absent-vs-present logic as the message, so a bounce-back keeps the admin's
    # edit; a blank subject falls back to the default at send time.
    @custom_subject = params.key?(:custom_subject) ? params[:custom_subject].to_s : helpers.default_reminder_subject(@event)

    if @sample_registration
      # Render in preview mode so the custom-message container is always present
      # in the markup for the live preview, even before any text is typed.
      mail = EventMailer.event_registration_reminder(@sample_registration, custom_message: @custom_message, custom_subject: @custom_subject, preview: true)
      @reminder_preview_html = mail.html_part&.body&.decoded
    end
  end

  # Interstitial between picking recipients and actually sending: it lists exactly
  # who will be emailed and shows the static subject + body composed on the picker,
  # so the admin confirms against a real preview instead of a browser dialog.
  def confirm_reminder
    authorize! @event, to: :send_reminder?
    @event = @event.decorate
    @event_registrations = selected_reminder_registrations
    @custom_message = params[:custom_message].to_s
    @custom_subject = params[:custom_subject].to_s

    if @event_registrations.empty?
      redirect_to preview_reminder_event_path(@event, custom_message: @custom_message, custom_subject: @custom_subject), alert: "Please select at least one recipient."
      return
    end

    mail = EventMailer.event_registration_reminder(@event_registrations.first, custom_message: @custom_message, custom_subject: @custom_subject)
    @reminder_subject = mail.subject
    @reminder_preview_html = mail.html_part&.body&.decoded
  end

  def send_reminder
    authorize! @event, to: :send_reminder?
    custom_message = params[:custom_message].to_s
    custom_subject = params[:custom_subject].to_s
    registrations = selected_reminder_registrations

    if registrations.empty?
      redirect_to preview_reminder_event_path(@event, custom_message: custom_message, custom_subject: custom_subject), alert: "Please select at least one recipient."
      return
    end

    # Record an individual notification per recipient (delivered + persisted via
    # NotificationMailerJob), so each reminder shows up in that person's
    # communication history and can be resent — like confirmations/cancellations.
    registrations.each do |event_registration|
      NotificationServices::CreateNotification.call(
        noticeable: event_registration,
        kind: "event_registration_reminder",
        recipient_role: :person,
        recipient_email: event_registration.registrant.preferred_email,
        notification_type: 0,
        sender: current_user, # an admin sent these by hand from the reminders page
        custom_message: custom_message.presence,
        custom_subject: custom_subject.presence
      )
    end

    # One admin summary for the whole batch: count, roster, and a copy of what
    # was sent. Roster passed as plain "Name <email>" labels so the delivery job
    # needs no record lookups.
    recipient_labels = registrations.map { |r| "#{r.registrant.full_name} <#{r.registrant.preferred_email}>" }
    EventMailer.event_registration_reminder_fyi(@event, recipient_labels, custom_message: custom_message.presence).deliver_later

    track_view("events.send_reminder", { event_id: @event.id, recipient_count: registrations.size })
    redirect_to registrants_event_path(@event), notice: "Reminder emails are being sent to #{registrations.size} registrant#{'s' if registrations.size != 1}."
  end

  def create
    authorize!
    @event = Event.new(event_params)
    @event.created_by ||= current_user

    success = false

    Event.transaction do
      if @event.save
        assign_associations(@event)
        assign_event_forms(@event)
        if params.dig(:library_asset, :new_assets).present?
          update_asset_owner(@event)
        end
        BuiltinCallouts.seed(@event)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
      Rails.logger.error "Event create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    respond_to do |format|
      if success
        format.html { redirect_to @event, notice: "Event was successfully created." }
        format.json { render :show, status: :created, location: @event }
      else
        set_form_variables
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @event.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    authorize! @event
    success = false

    Event.transaction do
      assign_event_forms(@event)
      @event.event_forms.reset
      if @event.update(event_params)
        assign_associations(@event)
        # Lazily materialize built-in callouts for events created before this
        # existed — heals on first edit, no data backfill. Idempotent.
        BuiltinCallouts.seed(@event)
        success = true
      else
        raise ActiveRecord::Rollback
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
      Rails.logger.error "Event update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    respond_to do |format|
      if success
        format.html { redirect_to dashboard_event_path(@event), notice: "Event was successfully updated." }
        format.json { render :show, status: :ok, location: @event }
      else
        set_form_variables
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @event.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    authorize! @event

    if @event.destroy
      respond_to do |format|
        format.html { redirect_to events_path, status: :see_other, notice: "Event was successfully destroyed." }
        format.json { head :no_content }
      end
    else
      message = @event.errors.full_messages.to_sentence.presence || "Event could not be destroyed."
      respond_to do |format|
        format.html { redirect_to event_path(@event), status: :see_other, alert: message }
        format.json { render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def copy_registration_form
    authorize! @event, to: :manage?

    source_event = Event.find(params[:source_event_id])
    source_form = source_event.registration_form

    if source_form
      @event.event_forms.find_or_create_by!(form: source_form, role: "registration")
      redirect_to edit_event_path(@event), notice: "Registration form linked successfully."
    else
      redirect_to edit_event_path(@event), alert: "Source event has no registration form."
    end
  end

  private

  # Where to land after saving staff: back to the origin the editor was opened
  # from (the sample preview, or a registrant's staff callout page), else the
  # admin staff roster. Kept in sync with the edit_staff eyebrow.
  def staff_update_return_path
    case params[:return_to]
    when "sample_staff" then sample_staff_event_path(@event)
    when "registration_staff"
      params[:reg].present? ? registration_staff_path(params[:reg]) : staff_event_path(@event)
    else staff_event_path(@event)
    end
  end

  # Authorize the cross-event report suite. An explicit event_id (from the
  # per-event Reports tab) is authorized against that event, so asking for one you
  # don't own fails loudly rather than silently returning nothing. The unfiltered
  # view is open to event owners as well as admins — EventPolicy's :reportable
  # scope narrows the rows, so clearing the event filter lands an owner on their
  # own events instead of bouncing them off an admin-only page.
  def authorize_report!
    @filter_event ||= Event.find_by(id: params[:event_id]) if params[:event_id].present?
    if @filter_event
      authorize! @filter_event, to: :event_reports?
    else
      authorize! to: :cross_event_reports?
    end
  end

  # The events whose rows the current user may see in the report suite: every
  # event for an admin, their own for an event owner. Every report query starts
  # here, so the filter params can only narrow, never widen.
  def reportable_events(base = Event.all)
    authorized_scope(base, as: :reportable)
  end

  # The attendees index's population filters. These are DEFAULTS, not a fixed base:
  # you can't filter into no-shows from a set that already excluded them, so the
  # base is every reportable registration and these narrow it. Unfiltered, the page
  # shows exactly what it always has — people who attended a facilitator training.
  # Opt out with EventRegistration::FILTER_ALL (the participation report's
  # all-outcomes and all-event-types drill-ins).
  DEFAULT_ATTENDANCE_STATUS = "attended".freeze
  DEFAULT_ATTENDEE_EVENT_TYPE = "trainings".freeze

  def attendee_attendance_status
    params[:attendance_status].presence || DEFAULT_ATTENDANCE_STATUS
  end

  def attendee_event_type
    params[:event_type].presence || DEFAULT_ATTENDEE_EVENT_TYPE
  end

  # The recipient cards, narrowed by a breakdown drill-in — same rule as the
  # roster: only the list shrinks, the breakdowns stay whole.
  def filtered_recipient_applicants
    ids = params[:registrant_ids].presence&.to_s&.split("-")&.map(&:to_i)&.to_set
    return @dashboard.scholarship_applicants unless ids
    @dashboard.scholarship_applicants.select { |person| ids.include?(person.id) }
  end

  # The roster table's rows, narrowed by a breakdown drill-in. Only the table
  # shrinks — the stat bar and the breakdowns deliberately stay whole, so the
  # charts remain the full picture and keep working as a navigation surface while
  # the table below shows what was clicked.
  def filtered_roster_registrants
    ids = roster_drill_in_ids
    return @dashboard.registrants unless ids
    @dashboard.registrants.select { |person| ids.include?(person.id) }
  end

  # Person ids behind the clicked breakdown row. Most dimensions arrive as an
  # explicit id list (EventDashboard already has the maps); sector and state have
  # no per-value id map, so they arrive as named filters and resolve here.
  def roster_drill_in_ids
    return @roster_drill_in_ids if defined?(@roster_drill_in_ids)

    @roster_drill_in_ids =
      if params[:registrant_ids].present?
        params[:registrant_ids].to_s.split("-").map(&:to_i).to_set
      elsif params[:sector].present?
        Person.where(id: person_sector_ids(params[:sector])).ids.to_set
      elsif params[:state].present?
        Person.where(id: person_address_ids(state: params[:state])).ids.to_set
      end
  end

  # The events the attendees index draws from: the viewer's reportable events
  # narrowed by the event-side filters. Shared by the registration scope and by the
  # roster/breakdowns, so a person's row only shows events in scope rather than
  # their whole history.
  def attendee_events
    @attendee_events ||= begin
      scope = reportable_events
      # Same vocabulary as the report suite's Event type filter, so the hub's
      # Attendees/Breakdowns links carry a Live or On-demand filter through instead
      # of falling through to every event type.
      scope = scope.facilitator_trainings if attendee_event_type == "trainings"
      scope = scope.facilitator_trainings.live if attendee_event_type == "live"
      scope = scope.facilitator_trainings.on_demand if attendee_event_type == "on_demand"
      scope = scope.where(facilitator_training: false) if attendee_event_type == "other"
      # Off @filter_event rather than the raw param: the policy scope already bounds
      # the events, and the resolved record is one event where params[:event_id]
      # could be an array asking for several.
      scope = scope.where(id: @filter_event.id) if @filter_event
      scope = scope.in_year(params[:event_year]) if params[:event_year].present?
      scope
    end
  end

  # Registrations (any registrant) on those events, narrowed by the registration-side
  # filters — the population behind the index and the basis for its org/scholarship/
  # CE drill-in filters.
  def attendee_registrations
    @attendee_registrations ||= begin
      scope = EventRegistration.where(event_id: attendee_events.select(:id))
      scope = scope.attendance_status(attendee_attendance_status) unless attendee_attendance_status == EventRegistration::FILTER_ALL
      scope = scope.payment_status(params[:payment_status]) if params[:payment_status].present?
      scope = scope.funder(params[:funder]) if params[:funder].present?
      scope
    end
  end

  # Ahoy log for a visit to an event page/report, e.g. "view.events.roster". Ties
  # the event via event_id where there is one (per-event pages, or a report scoped
  # to an event). Skips the lazy Turbo-frame sub-requests so a page counts once.
  def track_page_view
    return if turbo_frame_request? || response.redirect?
    track_view("events.#{action_name}", { event_id: @event&.id || params[:event_id].presence }.compact)
  end

  # Shared filter state for the revenue/participation/reports/scholarships report
  # pages: the event-type, specific-event and abbreviation-search filters, plus the
  # event list for the Event dropdown.
  def set_report_filters
    @event_type = params[:event_type].presence_in(%w[ trainings live on_demand other ])
    @filter_event = Event.find_by(id: params[:event_id]) if params[:event_id].present?
    @event_search = params[:search].presence
    @filter_funder = GlobalID::Locator.locate_signed(params[:funder_sgid]) if params[:funder_sgid].present?
    # The Event dropdown lists the report's own universe: paid events for revenue,
    # facilitator trainings for scholarships, every event otherwise.
    dropdown_scope = case action_name
    when "revenue" then Event.paid
    when "scholarships" then Event.facilitator_trainings
    else Event.all
    end
    # Only offer events the viewer may report on, so picking one from the dropdown
    # can never land them on a forbidden event.
    @filter_events = reportable_events(dropdown_scope).order(start_date: :desc)
  end

  # Applies the shared report filters (event type, specific event) plus a
  # calendar-year time period to `base` (the report's unfiltered relation, e.g.
  # Event.paid or Event.all). Sets @year_options and @time_period for the filter
  # form, and returns the decorated events plus the selected year (nil for "all
  # time").
  def filtered_report_events(base)
    base = scoped_report_base(base)
    @year_options = base.where.not(start_date: nil)
      .distinct
      .pluck(Arel.sql("YEAR(start_date)"))
      .sort
      .reverse
    @time_period = params[:time_period].presence || "all_time"
    selected_year = selected_report_year(@time_period)
    events = selected_year ? base.in_year(selected_year) : base
    [ events.order(start_date: :desc).map(&:decorate), selected_year ]
  end

  # Decorated events for a report, scoped by the shared filters, newest first.
  def report_events(base)
    scoped_report_base(base).order(start_date: :desc).map(&:decorate)
  end

  # Narrows `base` by the event-type, specific-event and search (abbreviation OR
  # title) filters.
  def scoped_report_base(base)
    base = reportable_events(base)
    base = base.facilitator_trainings if @event_type == "trainings"
    base = base.facilitator_trainings.live if @event_type == "live"
    base = base.facilitator_trainings.on_demand if @event_type == "on_demand"
    base = base.where(facilitator_training: false) if @event_type == "other"
    base = base.where(id: @filter_event.id) if @filter_event
    if @event_search
      like = "%#{Event.sanitize_sql_like(@event_search)}%"
      base = base.where("events.abbreviation LIKE :q OR events.title LIKE :q", q: like)
    end
    base = base.where(id: Scholarship.from_funder(@filter_funder).event_ids) if @filter_funder
    base
  end

  # The calendar year a report is scoped to: the current year for "this_year", a
  # specific year for a "2025"-style value, or nil for "all_time".
  def selected_report_year(time_period)
    return Date.current.year if time_period == "this_year"
    Integer(time_period, exception: false)
  end

  # People (Person records) behind the attendees index's registrations, narrowed by
  # the index filters. The event- and registration-side filters (see
  # #attendee_events / #attendee_registrations) constrain which registrations
  # qualify; the rest filter the people. Distinct via the id subquery, so joins
  # never duplicate rows.
  def filtered_attendees
    scope = Person.where(id: attendee_registrations.select(:registrant_id))
    # Dash-joined person ids, e.g. from the reports-hub participation totals.
    scope = scope.where(id: params[:registrant_ids].to_s.split("-")) if params[:registrant_ids].present?
    scope = scope.search_by_params({ contact_info: params[:contact_info] }) if params[:contact_info].present?
    scope = scope.where(id: person_sector_ids(params[:sector])) if params[:sector].present?
    scope = scope.where(id: person_affiliation_status_ids(params[:affiliation_status])) if params[:affiliation_status].present?
    # Breakdown drill-in filters (set when a chart row is clicked).
    scope = scope.where(id: person_category_ids(params[:age_group])) if params[:age_group].present?
    scope = scope.where(id: person_category_ids(params[:life_experience])) if params[:life_experience].present?
    scope = scope.where(id: person_category_ids(params[:setting])) if params[:setting].present?
    scope = scope.where(id: person_country_ids(params[:country])) if params[:country].present?
    scope = scope.where(id: person_school_district_ids(params[:school_district])) if params[:school_district].present?
    scope = scope.where(id: person_program_status_ids(params[:program_status])) if params[:program_status].present?
    scope = scope.where(id: person_linked_organization_ids(params[:organization_id])) if params[:organization_id].present?
    scope = scope.where(id: person_linked_org_city_ids(params[:org_city])) if params[:org_city].present?
    if params[:scholarship].present?
      ids = scholarship_recipient_person_ids
      scope = params[:scholarship] == "no" ? scope.where.not(id: ids) : scope.where(id: ids)
    end
    if params[:ce].present?
      ids = ce_person_ids
      scope = params[:ce] == "no" ? scope.where.not(id: ids) : scope.where(id: ids)
    end
    scope = scope.where(id: person_address_ids(state: params[:state])) if params[:state].present?
    if params[:county].present?
      # County options carry their state ("STATE::County") so same-named counties
      # across states don't collide.
      county_state, county_name = params[:county].split("::", 2)
      scope = scope.where(id: person_address_ids(state: county_state, county: county_name))
    end

    scope
      .includes(:affiliations, { sectorable_items: :sector }, { age_range_categorizable_items: { category: :category_type } })
      .order(:first_name, :last_name)
  end

  def person_sector_ids(sector_id)
    SectorableItem.where(sectorable_type: "Person", sector_id: sector_id).select(:sectorable_id)
  end

  # Person ids tagged with a given Category (age group / life experience / setting
  # all identify by category id).
  def person_category_ids(category_id)
    CategorizableItem.where(categorizable_type: "Person", category_id: category_id).select(:categorizable_id)
  end

  def person_country_ids(country)
    Address.active.where(addressable_type: "Person", country: country).select(:addressable_id)
  end

  def person_school_district_ids(district)
    Address.active.where(addressable_type: "Person", district: district).select(:addressable_id)
  end

  # Person ids with the given org linked on one of their in-scope registrations.
  def person_linked_organization_ids(organization_id)
    EventRegistrationOrganization
      .joins(:event_registration)
      .where(organization_id: organization_id, event_registration_id: attendee_registrations.select(:id))
      .select(Arel.sql("event_registrations.registrant_id"))
  end

  # People whose linked training org sits in the given "City, State" (matched on
  # each org's first active address, mirroring the cities breakdown's labeling).
  def person_linked_org_city_ids(city_label)
    org_ids = org_ids_by_city_label[city_label] || []
    return Person.none if org_ids.empty?
    person_linked_organization_ids(org_ids)
  end

  def org_ids_by_city_label
    @org_ids_by_city_label ||= Address.active
      .where(addressable_type: "Organization",
             addressable_id: EventRegistrationOrganization.where(event_registration_id: attendee_registrations.select(:id)).select(:organization_id))
      .order(:id)
      .pluck(:addressable_id, :city, :state)
      .each_with_object({}) do |(org_id, city, state), first_label|
        next if first_label.key?(org_id)
        first_label[org_id] = [ city, state ].compact_blank.join(", ").presence
      end
      .group_by { |_org_id, label| label }
      .transform_values { |pairs| pairs.map(&:first) }
  end

  # Person ids whose linked training org currently has the given facilitator
  # program status (new / ongoing / reinstated).
  def person_program_status_ids(status)
    status_sym = status.to_sym
    org_ids = Organization
      .where(id: EventRegistrationOrganization.where(event_registration_id: attendee_registrations.select(:id)).select(:organization_id))
      .includes(:affiliations)
      .select { |organization| organization.facilitator_status_on(Date.current) == status_sym }
      .map(&:id)
    return Person.none if org_ids.empty?
    person_linked_organization_ids(org_ids)
  end

  def scholarship_recipient_person_ids
    EventRegistration
      .where(id: Allocation.where(source_type: "Scholarship", allocatable_type: "EventRegistration", allocatable_id: attendee_registrations.select(:id)).select(:allocatable_id))
      .select(:registrant_id)
  end

  def ce_person_ids
    EventRegistration
      .where(id: ContinuingEducationRegistration.where(event_registration_id: attendee_registrations.select(:id)).select(:event_registration_id))
      .select(:registrant_id)
  end

  # Person ids with at least one affiliation in the given status (Active / Pending
  # / Inactive).
  def person_affiliation_status_ids(status)
    Affiliation.with_status(status).select(:person_id)
  end

  def person_address_ids(state: nil, county: nil)
    scope = Address.active.where(addressable_type: "Person")
    scope = scope.where(state: state) if state.present?
    scope = scope.where(county: county) if county.present?
    scope.select(:addressable_id)
  end

  # Option lists for the attendees index filter selects, built once per full page
  # load from the viewer's WHOLE reportable population — deliberately un-narrowed by
  # the active filters, so filtering never removes the option that would undo it.
  def set_attendee_filter_options
    @attendee_event_options = reportable_events.order(start_date: :desc)
    @attendee_years = @attendee_event_options.filter_map { |event| event.start_date&.year }.uniq.sort.reverse
    person_ids = Person.where(id: EventRegistration.where(event_id: reportable_events.select(:id)).select(:registrant_id))
    @attendee_sectors = Sector.where(id: SectorableItem.where(sectorable_type: "Person", sectorable_id: person_ids).select(:sector_id)).order(:name)
    addresses = Address.active.where(addressable_type: "Person", addressable_id: person_ids)
    @attendee_states = addresses.where.not(state: [ nil, "" ]).distinct.pluck(:state).sort
    @attendee_counties = addresses.where.not(county: [ nil, "" ]).where.not(state: [ nil, "" ]).distinct.pluck(:state, :county).sort
  end

  # The registrations the admin checked on the recipient picker, narrowed to those
  # we can actually email. Shared by the confirm interstitial and the send action
  # so both operate on exactly the same set.
  def selected_reminder_registrations
    allowed_ids = Array(params[:registration_ids]).map(&:to_i).reject(&:zero?)
    @event.event_registrations
      .where(id: allowed_ids)
      .includes(registrant: [ :user, :contact_methods ])
      .select { |r| r.registrant.preferred_email.present? }
  end

  # Maps registrant person_id => the organization name they typed on the
  # registration form (the `agency_name` answer), in one batch query. Drives both
  # the roster's Pending/None org chip and the readiness "Organization not linked"
  # check, so both read the same resolved answer.
  def submitted_org_names_for(registrations)
    registration_form = @event.registration_form
    field = registration_form&.form_fields&.find_by(field_identifier: "agency_name")
    return {} unless field

    FormAnswer.joins(:form_submission)
      .where(form_submissions: { person_id: registrations.map(&:registrant_id), form_id: registration_form.id }, form_field_id: field.id)
      .pluck(Arel.sql("form_submissions.person_id"), :submitted_answer)
      .to_h
  end

  def event_registrations_csv_string
    require "csv"
    cost_required = @event.cost_cents.to_i > 0
    include_ce = @event.ce_eligible?
    headers = [ "First name", "Last name", "Email", "Phone", "Organization", "Scholarship recipient", "Scholarship tasks completed", "Payment status", "Expected payment method", "Intends to pay", "Someone else will pay", "Payment total" ]
    headers += [ "CE status", "CE paid", "CE due" ] if include_ce
    CSV.generate(headers: headers, write_headers: true) do |csv_out|
      @event_registrations.each do |registration|
        csv_out << event_registration_csv_row(registration, cost_required, include_ce)
      end
    end
  end

  def event_registration_csv_row(registration, cost_required, include_ce = false)
    person = registration.registrant
    orgs = person.affiliations
      .select { |a| !a.inactive? && (a.end_date.nil? || a.end_date >= Date.current) }
      .map(&:organization).compact.uniq
    org_names = orgs.map(&:name).join("; ")
    total_cents = registration.allocations_sum
    payment_total = csv_dollars(total_cents)
    payment_status = cost_required ? registration.payment_status_label : ""
    row = [
      person.first_name,
      person.last_name,
      person.preferred_email.presence || "",
      person.phone_number.presence || "",
      org_names.presence || "",
      registration.scholarships.any? ? "Yes" : "No",
      registration.scholarships.any?(&:tasks_completed?) ? "Yes" : "No",
      payment_status,
      cost_required ? registration.expected_payment_method.presence || "" : "",
      registration.intends_to_pay? ? "Yes" : "No",
      cost_required ? (registration.someone_else_will_pay? ? "Yes" : "No") : "",
      payment_total
    ]
    if include_ce
      row << registration.ce_status_label.to_s
      row << csv_dollars(registration.ce_amount_paid_cents)
      row << csv_dollars(registration.ce_amount_due_cents)
    end
    row
  end

  def onboarding_csv_string
    require "csv"
    cost_required = @event.cost_cents.to_i > 0
    include_ce = @event.ce_eligible?
    day_count = @event.day_count
    headers = [ "First name", "Last name", "Email", "Organization", "Program type" ]
    headers += [ "Payment status", "Fees due", "Paid amount" ] if cost_required
    headers << "Fee note"
    headers += [ "Discounted amount", "Scholarship amount", "Scholarship grant", "Scholarship tasks completed" ]
    headers += [ "CE requested", "CE hours", "CE amount", "CE paid", "CE due", "CE license" ] if include_ce
    headers += EventRegistration::CHECKLIST_STEPS.values
    headers += [ "Portal user status", "Portal access" ]
    headers += (1..day_count).map { |day| "Day #{day}" }
    headers << "Attendance status"
    headers += [ "Comments", "Flagged comments" ]

    CSV.generate(headers: headers, write_headers: true) do |csv_out|
      @event_registrations.each do |registration|
        csv_out << onboarding_csv_row(registration, cost_required, day_count, include_ce)
      end
    end
  end

  def onboarding_csv_row(registration, cost_required, day_count, include_ce = false)
    person = registration.registrant
    scholarship = registration.scholarships.first
    statuses = registration.program_statuses.map { |status| status.to_s.titleize }.join(", ")

    row = [
      person.first_name,
      person.last_name,
      person.preferred_email.presence || "",
      registration.organizations.map(&:name).join("; ").presence || "",
      statuses
    ]
    if cost_required
      due_cents = [ @event.cost_cents.to_i - registration.allocations_sum, 0 ].max
      row << registration.payment_status_label
      row << helpers.dollars_from_cents(due_cents)
      row << helpers.dollars_from_cents(registration.payments_sum)
    end
    row << registration.fee_note.to_s
    row << csv_dollars(registration.discount_sum)
    row << (scholarship ? helpers.dollars_from_cents(scholarship.amount_cents) : "")
    row << (scholarship ? (scholarship.grant&.name.presence || "Unfunded") : "")
    row << onboarding_scholarship_tasks_csv(registration)
    if include_ce
      ce_hours = registration.ce_hours_total
      row << (registration.ce_registered? ? "Yes" : "No")
      row << (ce_hours.positive? ? helpers.plain_number(ce_hours) : "")
      row << csv_dollars(registration.ce_amount_owed_cents)
      row << csv_dollars(registration.ce_amount_paid_cents)
      row << csv_dollars(registration.ce_amount_due_cents)
      row << registration.ce_license_numbers.join("; ")
    end
    EventRegistration::CHECKLIST_STEPS.each_key do |step|
      row << (registration.checklist_step_completed?(step) ? "Yes" : "No")
    end
    account_status = registration.account_status
    row << { "none" => "No account", "has_access" => "Has access", "invited" => "Invited", "no_access" => "No access" }.fetch(account_status, account_status.to_s.humanize)
    row << (account_status == "has_access" ? "Yes" : "No")
    (1..day_count).each do |day|
      row << (registration.public_send("completed_day_#{day}") ? "Yes" : "No")
    end
    row << registration.attendance_status_label
    row << registration.comments.map { |comment| comment.body.to_s.strip }.reject(&:blank?).join(" ::: ")
    row << (registration.comments.any?(&:flagged?) ? "Yes" : "No")
    row
  end

  def onboarding_scholarship_tasks_csv(registration)
    scholarships = registration.scholarships
    return "" if scholarships.none?
    scholarships.all?(&:tasks_completed?) ? "Yes" : "No"
  end

  def assign_event_forms(event)
    assign_event_form(event, :registration, params.dig(:event, :registration_form_id))
    assign_event_form(event, :scholarship, params.dig(:event, :scholarship_form_id))
    assign_event_form(event, :bulk_payment, params.dig(:event, :bulk_payment_form_id))
    assign_event_form(event, :continuing_education, params.dig(:event, :continuing_education_form_id))
  end

  def assign_event_form(event, role, form_id)
    if form_id.blank?
      event.event_forms.where(role: role).destroy_all
    elsif form = Form.standalone.find_by(id: form_id)
      ef = event.event_forms.find_or_create_by!(role: role) { |r| r.form = form }
      ef.update!(form: form) unless ef.form_id == form.id.to_i
    end
  end

  def set_form_variables
    @event = @event.decorate
    @event.build_primary_asset if @event.primary_asset.blank?
    @event.gallery_assets.build
    # Build any not-yet-present built-in callouts as in-memory rows so the editor
    # shows them (editable, with builtin_key round-tripped) even before the event's
    # first save. Idempotent, so it's a no-op once they exist (edit seeds real
    # rows first; a failed create/update already carries the submitted rows).
    BuiltinCallouts.build(@event)
    @locations = Location.order(:city, :state)
    @registration_forms = Form.standalone.where(role: "registration").order(:name)
    @scholarship_forms = Form.standalone.where(role: "scholarship").order(:name)
    @bulk_payment_forms = Form.standalone.where(role: "bulk_payment").order(:name)
    @continuing_education_forms = Form.standalone.where(role: "continuing_education").order(:name)
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:position, :name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || (type.published? && !type.story_specific? && !type.profile_specific?) }
        .sort_by { |type, _| type&.name.to_s.downcase }
    @sectors = Sector.published.order(:name)
  end

  # The registrant's profile bio as plain text, usable to seed a shout-out — only
  # when the bio is shown on their profile. Nil when hidden or blank.
  def shoutout_bio_from_profile(person)
    return unless person.profile_show_bio?
    helpers.strip_tags(person.bio).to_s.strip.presence
  end

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    authorized(params.require(:event))
  end

  def event_staff_params
    params.require(:event).permit(
      event_staffs_attributes: [ :id, :person_id, :title, :expected_to_attend, :bio, :_destroy ]
    )
  end
end
