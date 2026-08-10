class ScholarshipsController < ApplicationController
  before_action :set_scholarship, only: [ :show, :edit, :update, :destroy, :toggle_tasks ]
  before_action :set_grant, only: [ :new, :create ]

  def index
    authorize! Scholarship
    set_report_filter_state
    scholarships = filtered_scholarships
    @funder_groups = ScholarshipsGrouping.new(scholarships).funder_groups
    @scholarships_count = scholarships.size
    @scholarship_report = EventScholarshipReport.new(report_training_events, featured_year: @selected_year, funder: @filter_funder)
  end

  def show
    @scholarship = Scholarship.find(params[:id])
    authorize! @scholarship
  end

  def new
    if @grant
      @scholarship = Scholarship.new(grant: @grant)
      authorize! @scholarship
      return
    end

    @allocatable = locate_allocatable
    redirect_to allocations_path, alert: "Allocatable not found." and return unless @allocatable

    @scholarship = Scholarship.new(recipient: @allocatable.registrant)
    @grants = Grant.selectable_for(@scholarship)
    authorize! @scholarship
    load_scholarship_submission
  end

  def create
    if @grant
      @scholarship = Scholarship.new(scholarship_params.merge(grant: @grant))
      authorize! @scholarship

      if @scholarship.save
        redirect_to grant_return_path, notice: "Scholarship created."
      else
        render :new, status: :unprocessable_content
      end
      return
    end

    @allocatable = locate_allocatable
    redirect_to allocations_path, alert: "Allocatable not found." and return unless @allocatable

    @scholarship = Scholarship.new(scholarship_params.merge(recipient: @allocatable.registrant))
    @scholarship.build_allocation(allocatable: @allocatable, amount: @scholarship.amount_cents.to_i)
    authorize! @scholarship

    if @scholarship.save
      redirect_to scholarship_save_path, notice: "Scholarship created."
    else
      @grants = Grant.selectable_for(@scholarship)
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @allocatable = @scholarship.allocation&.allocatable
    @grants = Grant.selectable_for(@scholarship)
    authorize! @scholarship
    load_scholarship_submission
  end

  def update
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship

    @scholarship.assign_attributes(scholarship_params)
    attribute_comment_authorship

    # Inline-logged notifications are addressed to the scholarship recipient.
    recipient_email = @scholarship.recipient&.preferred_email.presence || "n/a"
    @scholarship.notifications.select(&:new_record?).each { |n| n.recipient_email = recipient_email }

    if @scholarship.save
      redirect_to scholarship_save_path, notice: "Scholarship updated."
    else
      @grants = Grant.selectable_for(@scholarship)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship
    grant = @scholarship.grant
    @scholarship.destroy!

    redirect_to scholarship_return_path(grant), notice: "Scholarship removed."
  end

  # Flip a recipient's tasks-completed state from the event recipients roster.
  # The model's after_update allocates the award when complete and de-allocates
  # it when outstanding, so this single toggle finalizes or unwinds the award.
  def toggle_tasks
    authorize! @scholarship, to: :update?
    @scholarship.update!(tasks_completed: !@scholarship.tasks_completed?)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: recipients_fallback_path, notice: "Scholarship updated." }
    end
  end

  private

  # Filter state for the shared report filter partials (time period, event,
  # abbreviation, funder). The Event dropdown and year options list facilitator
  # trainings, matching the events scholarship report.
  def set_report_filter_state
    @filter_event = Event.find_by(id: params[:event_id]) if params[:event_id].present?
    @event_search = params[:search].presence
    @filter_funder = GlobalID::Locator.locate_signed(params[:funder_sgid]) if params[:funder_sgid].present?
    @filter_events = Event.facilitator_trainings.order(start_date: :desc)
    @year_options = Event.facilitator_trainings
      .where.not(start_date: nil)
      .distinct
      .pluck(Arel.sql("YEAR(start_date)"))
      .sort
      .reverse
    @time_period = params[:time_period].presence || "all_time"
    @selected_year = @time_period == "this_year" ? Date.current.year : Integer(@time_period, exception: false)
  end

  # The scholarship list, narrowed by recipient, funder, and the event-centric
  # filters (which resolve to the events a scholarship was awarded at).
  def filtered_scholarships
    # Eager-load everything the grid derives so each row's funder, program,
    # location, training, and status cells add no per-row queries.
    scope = authorized_scope(Scholarship.all).includes(
      { grant: :funder },
      { recipient: [ { affiliations: { organization: :addresses } }, { event_registrations: :event } ] }
    )
    if params[:recipient_id].present?
      scope = scope.where(recipient_id: params[:recipient_id])
      @recipient = Person.find_by(id: params[:recipient_id])
    end
    scope = scope.from_funder(@filter_funder) if @filter_funder
    event_ids = filter_event_ids
    scope = scope.for_events(event_ids) if event_ids
    scope
  end

  # Event ids matching the year / specific-event / search filters, or nil
  # when none are active (so the list isn't restricted by event).
  def filter_event_ids
    return unless @selected_year || @filter_event || @event_search
    scoped_events.select(:id)
  end

  # Facilitator trainings for the summary report at the top of the index, scoped
  # by the same filters (year / event / search / funder), decorated.
  def report_training_events
    events = scoped_events(Event.facilitator_trainings)
    events = events.where(id: Scholarship.from_funder(@filter_funder).event_ids) if @filter_funder
    events.order(start_date: :desc).map(&:decorate)
  end

  # Applies the year / specific-event / search (abbreviation OR title) filters to
  # an event scope.
  def scoped_events(base = Event.all)
    base = base.in_year(@selected_year) if @selected_year
    base = base.where(id: @filter_event.id) if @filter_event
    if @event_search
      like = "%#{Event.sanitize_sql_like(@event_search)}%"
      base = base.where("events.abbreviation LIKE :q OR events.title LIKE :q", q: like)
    end
    base
  end

  def set_scholarship
    @scholarship = Scholarship.find(params[:id])
  end

  # The recipients roster the tasks toggle is operated from — used as the
  # fallback when there's no referer to return to.
  def recipients_fallback_path
    event = @scholarship.allocation&.allocatable.try(:event)
    event ? recipients_event_path(event) : root_path
  end

  def set_grant
    @grant = Grant.find(params[:grant_id]) if params[:grant_id].present?
  end

  # A scholarship can be both event-funded and grant-funded. The return_to param
  # records which page the user came from so navigation follows that context
  # rather than always preferring the event.
  def grant_context?(grant = @scholarship&.grant)
    grant.present? && params[:return_to].in?(%w[ grant_show grant_edit ])
  end

  # Return to the grant the user came from (its show or edit page, respectively).
  def grant_return_path(grant = @scholarship.grant)
    params[:return_to] == "grant_edit" ? edit_grant_path(grant) : grant_path(grant)
  end

  # After saving, return to wherever the user came from: the grant, the event
  # registration's edit page (the card's Edit link carries return_to=registration),
  # the registrants roster (the roster's links carry no return_to), or — by
  # default — stay on the scholarship's own edit page.
  def scholarship_save_path
    return grant_return_path if grant_context?

    if @allocatable.respond_to?(:event)
      return edit_event_registration_path(@allocatable) if params[:return_to] == "registration"
      return recipients_return_path(@allocatable.event) if params[:return_to] == "recipients"
      return helpers.onboarding_event_row_path(@allocatable.event, @allocatable.id) if params[:return_to] == "onboarding"
      return registrants_event_path(@allocatable.event)
    end

    edit_scholarship_path(@scholarship)
  end

  # Return to the recipients roster, scrolling back to the participant card the
  # Edit link was opened from (its slug rides along in the participant param).
  def recipients_return_path(event)
    helpers.recipients_event_card_path(event, params[:participant])
  end

  # After destroying, leave the scholarship entirely: back to the grant when that
  # is the context, otherwise the event registrants page, otherwise normal fallback.
  def scholarship_return_path(grant)
    return grant_return_path(grant) if grant_context?(grant)

    event = @allocatable.try(:event)
    if event
      return recipients_return_path(event) if params[:return_to] == "recipients"
      return helpers.onboarding_event_row_path(event, @allocatable.id) if params[:return_to] == "onboarding" && @allocatable.respond_to?(:id)
      return registrants_event_path(event)
    end
    return grant_path(grant) if grant

    root_path
  end

  # Pull the recipient's scholarship-application answers — wherever they were
  # captured (dedicated scholarship form, embedded registration section, or
  # against the registration submission) — plus a link to the full submission.
  def load_scholarship_submission
    return unless @allocatable.respond_to?(:event)

    @event = @allocatable.event
    return unless @event

    application = ScholarshipApplication.new(event: @event, person: @scholarship.recipient)
    @form_submission = application.submission
    @scholarship_answers = application.answer_pairs
  end

  def locate_allocatable
    sgid = params[:allocatable_sgid] || params.dig(:scholarship, :allocatable_sgid)
    GlobalID::Locator.locate_signed(sgid) if sgid
  end

  def scholarship_params
    params.require(:scholarship).permit(
      :amount_dollars, :amount_cents, :tasks_completed, :agreement_signed, :grant_id, :recipient_id,
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      notifications_attributes: [ :id, :channel, :sender_id, :email_subject, :email_body_text, :noticeable_type, :noticeable_id, :_destroy ]
    )
  end

  # Stamp authorship on comments edited through the scholarship form: author + editor
  # on new ones, editor on existing ones whose body changed.
  def attribute_comment_authorship
    @scholarship.comments.select(&:new_record?).each do |c|
      c.created_by = current_user
      c.updated_by = current_user
    end
    @scholarship.comments.select { |c| c.persisted? && c.body_changed? }.each do |c|
      c.updated_by = current_user
    end
  end
end
