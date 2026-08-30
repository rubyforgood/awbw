class EventRegistrationsController < ApplicationController
  require "csv"

  # show redirects to slug URL; kept for backwards compatibility
  before_action :set_event_registration, only: [ :show, :edit, :update, :destroy, :update_onboarding, :toggle_certificate_issued, :update_attendance, :transfer, :process_transfer, :revert_transfer ]
  # A transferred-out reg is locked (issue #1944): its inline write endpoints are
  # blocked with a warning rather than silently ignored. The full-form `update` is
  # handled separately (it keeps comments/communications editable).
  before_action :block_locked_registration, only: [ :update_onboarding, :toggle_certificate_issued, :update_attendance ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(EventRegistration.all)
    filtered = base_scope.search_by_params(params)
    @event_registrations_count = filtered.size
    registrant_includes = [ :user, { avatar_attachment: :blob } ]
    # The phone/scholarship/payment/CE cells are CSV-only, so preload what they
    # read (per-row queries otherwise) without eager-loading it for the HTML index.
    registrant_includes << :contact_methods if request.format.csv?
    includes = [ { registrant: registrant_includes }, { event: :event_forms } ]
    includes += [ :allocations, :scholarships, { continuing_education_registrations: [ :professional_license, :allocations ] } ] if request.format.csv?
    @event_registrations = filtered.includes(includes).paginate(page: params[:page], per_page: per_page)
    @events = Event.order(start_date: :desc)
    @event_years = Event.where.not(start_date: nil).distinct.pluck(Arel.sql("YEAR(start_date)")).sort.reverse
    @organizations = authorized_scope(Organization.all, as: :affiliated).order(:name)
    @filtered_event = Event.find_by(id: params[:event_id]) if params[:event_id].present?
    @selected_registrant = Person.find_by(id: params[:registrant_id]) if params[:registrant_id].present?


    respond_to do |format|
      format.html
      format.csv do
        send_data csv_export(@event_registrations),
                  filename: "event_registrations_#{Time.current.to_fs(:number)}.csv",
                  type: "text/csv",
                  disposition: "attachment"
      end
    end
  end

  def show
    authorize! @event_registration

    if @event_registration.slug.present?
      redirect_to registration_ticket_path(@event_registration.slug), status: :moved_permanently
    else
      redirect_to edit_event_registration_path(@event_registration)
    end
  end

  def new
    @event_registration = EventRegistration.new(event_id: params[:event_id])
    authorize! @event_registration
    set_form_variables
  end

  def edit
    authorize! @event_registration
    set_form_variables
    registration_form = @event_registration.event&.registration_form
    @form_submission = registration_form && @event_registration.registrant.form_submissions
      .where(form: registration_form, event: @event_registration.event)
      .order(:created_at).first

    if @event_registration.checkout_session_id.present? &&
       @event_registration.payment_unresolved.nil? &&
       stripe_session = Stripe::Checkout::Session.retrieve(@event_registration.checkout_session_id)
      @checkout_payment_status = stripe_session.payment_status
    end
  end

  def create
    @event_registration = EventRegistration.new(event_registration_params)
    authorize! @event_registration

    if @event_registration.save
      respond_to do |format|
        format.html {
          redirect_to confirm_event_registration_path(@event_registration, return_to: params[:return_to])
        }
      end
    else
      redirect_after_failed_create(@event_registration.errors.full_messages.to_sentence)
    end
  rescue ActiveRecord::RecordNotUnique
    # The uniqueness validation isn't atomic with the insert, so a concurrent
    # request or double-submit can slip past it and hit the DB unique index on
    # (registrant_id, event_id). Treat it the same as a duplicate validation
    # failure instead of surfacing a 500.
    redirect_after_failed_create("This person is already registered for this event.")
  end

  def update
    authorize! @event_registration
    warn_if_locked_fields_submitted
    @event_registration.assign_attributes(event_registration_update_params)
    @event_registration.comments.select(&:new_record?).each { |c| c.created_by = current_user; c.updated_by = current_user }
    @event_registration.comments.select { |c| c.persisted? && c.body_changed? }.each { |c| c.updated_by = current_user }

    if @event_registration.save
      # Marking transferred out — from the edit-form save OR the inline roster/
      # onboarding status chip (Turbo) — with no destination yet sends the admin
      # to the transfer screen to create/link the incoming registration. Handled
      # before respond_to so both the HTML and Turbo paths redirect (issue #1944).
      if @event_registration.saved_change_to_status? &&
         @event_registration.transfer_destination_pending? &&
         allowed_to?(:transfer?, @event_registration)
        return redirect_to transfer_event_registration_path(@event_registration, return_to: params[:return_to]), status: :see_other
      end

      notice = "Registration was successfully updated."
      respond_to do |format|
        format.turbo_stream
        format.html {
          case params[:return_to]
          when "registrants" then redirect_to helpers.registrants_event_row_path(@event_registration.event, @event_registration.id), notice: notice, status: :see_other
          when "index" then redirect_to event_registrations_path, notice: notice, status: :see_other
          when "ticket" then redirect_to registration_ticket_path(@event_registration.slug), notice: notice, status: :see_other
          when "preview_reminder" then redirect_to preview_reminder_event_path(@event_registration.event), notice: notice, status: :see_other
          when "onboarding" then redirect_to helpers.onboarding_event_row_path(@event_registration.event, @event_registration.id), notice: notice, status: :see_other
          when "attendees" then redirect_to attendees_events_path, notice: notice, status: :see_other
          when "roster" then redirect_to roster_event_path(@event_registration.event), notice: notice, status: :see_other
          when "reconcile_affiliations" then redirect_to reconcile_affiliations_event_path(@event_registration.event, anchor: helpers.dom_id(@event_registration, :attendance_status)), notice: notice, status: :see_other
          # Two ways back to the recipients page: the shout-outs section (the
          # feature-a-shout-out flow) or the recipient's own card (their name).
          when "recipients" then redirect_to recipients_event_path(@event_registration.event, anchor: "shout-outs"), notice: notice, status: :see_other
          when "recipient_card" then redirect_to helpers.recipients_event_card_path(@event_registration.event, @event_registration.slug), notice: notice, status: :see_other
          when "attendance" then redirect_to attendance_event_path(@event_registration.event), notice: notice, status: :see_other
          else
            # No explicit origin: keep admins in the management context (the
            # registrants list) rather than dropping them on the public
            # registration show.
            if allowed_to?(:manage?, with: EventRegistrationPolicy)
              redirect_to helpers.registrants_event_row_path(@event_registration.event, @event_registration.id), notice: notice, status: :see_other
            else
              redirect_to registration_ticket_path(@event_registration.slug), notice: notice, status: :see_other
            end
          end
        }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.html do
          set_form_variables
          render :edit, status: :unprocessable_content
        end
      end
    end
  end

  # Inline toggle/edit of a single onboarding column from the event's Onboarding
  # matrix. `field` is one of EventRegistration::CHECKLIST_STEPS (audited row),
  # EventRegistration::DAY_FIELDS (plain boolean), or "fee_note" (free text).
  def update_onboarding
    authorize! @event_registration, to: :update_onboarding?
    @field = params[:field].to_s
    @day_count = @event_registration.event.day_count
    completed = ActiveModel::Type::Boolean.new.cast(params[:value])

    if @field == "fee_note"
      @event_registration.update(fee_note: params[:value])
    elsif EventRegistration::DAY_FIELDS.include?(@field)
      @event_registration.update(@field => completed)
      # Toggling a day rolls the attendance status forward/back (registered →
      # incomplete_attendance → attended). Flag it so the badge re-renders too.
      @status_synced = @event_registration.sync_attendance_status_to_days!
    elsif EventRegistration::CHECKLIST_STEPS.key?(@field)
      toggle_checklist_step(@field, completed)
      @event_registration.checklist_completions.reload
    else
      return head :unprocessable_content
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to helpers.onboarding_event_row_path(@event_registration.event, @event_registration.id) }
    end
  end

  # Inline toggle of the "certificate issued" flag from the registrants roster.
  # Replaces just the cell so the whole roster doesn't re-render on every toggle.
  def toggle_certificate_issued
    authorize! @event_registration, to: :toggle_certificate_issued?
    @event_registration.mark_certificate_issued!(ActiveModel::Type::Boolean.new.cast(params[:value]))
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to helpers.registrants_event_row_path(@event_registration.event, @event_registration.id) }
    end
  end

  # Inline correction of one registrant's sign-in/out times for one training day, from
  # the event's attendance report. Rows carry clock times only — the day comes from the
  # report section the editor was opened in — plus a blank row to add a session and a
  # Remove box to drop one. Registrants edit their own times from the CE callout; this
  # is the same editor for staff, without leaving the report.
  def update_attendance
    authorize! @event_registration, to: :update_attendance?
    date = AttendanceDayRows.date_from(params[:date])
    return head :unprocessable_content unless date

    rows = AttendanceDayRows.new(params, date)
    EventAttendanceEntriesUpdate.new(@event_registration, rows.entry_attributes, editor: current_user).save!
    redirect_to attendance_report_path(date), notice: "Attendance times updated.", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = error_sentence(e.record)
    # Hand the submitted times back so a rejected save doesn't cost the admin what
    # they typed; the editor reopens on this cell prefilled with them.
    flash[:attendance_rows] = rows.submitted
    redirect_to attendance_report_path(date, reopen: true), status: :see_other
  end

  # Follow-up screen shown after a registration is marked "transferred out":
  # pick the destination event so the incoming registration is created/linked
  # and the transfer trail is preserved (issue #1944).
  def transfer
    authorize! @event_registration, to: :transfer?
    @return_to = params[:return_to]
    @events = transfer_destination_events
  end

  def process_transfer
    authorize! @event_registration, to: :transfer?
    destination_event = Event.find(params[:destination_event_id])

    # Enforce the same-format rule server-side, not just in the picker: an event
    # only transfers to another of its own format (on-demand ↔ on-demand). (#1944)
    unless transfer_destination_events.exists?(destination_event.id)
      redirect_to transfer_event_registration_path(@event_registration, return_to: params[:return_to].presence),
        alert: "You can only transfer to another #{@event_registration.event.on_demand? ? "on-demand" : "scheduled"} event.",
        status: :see_other
      return
    end

    # The registrant may already be registered for the destination event, which
    # would collide with the (registrant, event) uniqueness rule — link that
    # record as the transfer target instead of creating a duplicate.
    destination = EventRegistration.find_or_initialize_by(
      registrant_id: @event_registration.registrant_id,
      event_id: destination_event.id
    )
    # Collapse a double transfer (A→B→C) to two live regs: when the reg being
    # transferred out is itself a transfer-in, its predecessor is the real origin,
    # so the new reg points straight there and the middle stop is dropped. (#1944)
    source = @event_registration.transferred_from_registration || @event_registration

    if destination == source
      # Transferring back to the origin event undoes the whole chain: restore the
      # origin to the status it held before it was transferred out, instead of
      # linking it to itself.
      destination.status = destination.status_before_transfer.presence || "registered"
      destination.status_before_transfer = nil
    else
      destination.transferred_from_registration = source
      # Copy the registrant's progress/profile state forward so the new reg reflects
      # where they left off (money & CE resolve separately). Days attended, expected
      # payment method, buddy-pay, and the recipients-page feature/shout-out flag. (#1944)
      # Days attended carry per-day, compressing when the source had more days than
      # the destination so no completion is lost off the end.
      copied = {
        expected_payment_method: @event_registration.expected_payment_method,
        someone_else_will_pay: @event_registration.someone_else_will_pay,
        shoutout: @event_registration.shoutout
      }
      copied.merge!(@event_registration.day_completion_carried_to(destination_event.day_count))
      destination.assign_attributes(copied)
    end

    saved = ActiveRecord::Base.transaction do
      # Re-pointing a completed transfer to a different event: unlink the previously
      # recorded destination (it becomes a standalone reg) and re-merge its CE back
      # to the source before re-splitting to the newly chosen event. (#1944)
      previous = @event_registration.transferred_to_registration
      if previous && previous.event_id != destination_event.id
        EventRegistrationServices::TransferContinuingEducation.new(
          transferred_out: @event_registration, destination: previous
        ).revert
        previous.update!(transferred_from_registration: nil)
      end
      next false unless destination.save
      # Carry the transferring reg's org links onto the destination so the new reg
      # shares the same linked organizations — copied, not moved, so the source
      # keeps its own. Read before the middle reg is dropped below. (#1944)
      @event_registration.organizations.each do |organization|
        destination.event_registration_organizations.find_or_create_by!(organization: organization)
      end
      # Split/relocate CE before dropping a collapsing middle reg, so its record
      # moves forward instead of being cascade-destroyed with the reg. (#1944)
      EventRegistrationServices::TransferContinuingEducation.new(
        transferred_out: @event_registration, destination: destination
      ).call
      @event_registration.destroy! if @event_registration.transferred_in?
      true
    end

    if saved
      redirect_to edit_event_registration_path(destination, return_to: params[:return_to].presence),
        notice: "Transfer recorded — #{source.registrant.full_name} is now registered for #{destination_event.title}.",
        status: :see_other
    else
      @return_to = params[:return_to]
      @events = transfer_destination_events
      flash.now[:alert] = destination.errors.full_messages.to_sentence
      render :transfer, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to transfer_event_registration_path(@event_registration, return_to: params[:return_to].presence),
      alert: "Select a destination event to transfer to.", status: :see_other
  end

  # Undo a transfer-out: restore the reg to its pre-transfer status, and (when a
  # destination was already recorded) unlink that destination and re-merge its CE
  # back to the source. (#1944)
  def revert_transfer
    authorize! @event_registration, to: :transfer?
    unless EventRegistrationServices::RevertTransfer.call(registration: @event_registration)
      redirect_to edit_event_registration_path(@event_registration, return_to: params[:return_to].presence),
        alert: "This registration isn't transferred out.", status: :see_other
      return
    end

    redirect_to edit_event_registration_path(@event_registration, return_to: params[:return_to].presence),
      notice: "Transfer undone — #{@event_registration.registrant.full_name} is back to #{@event_registration.attendance_status_label.downcase} on #{@event_registration.event.title}.",
      status: :see_other
  end

  def confirm
    @event_registration = EventRegistration.includes(registrant: :user, event: :location).find(params[:id])
    authorize! @event_registration, to: :confirm?
    @person = @event_registration.registrant
    @user = @person.user
    @return_to = params[:return_to]
  end

  def process_confirm
    @event_registration = EventRegistration.includes(registrant: :user).find(params[:id])
    authorize! @event_registration, to: :process_confirm?

    result = EventRegistrationServices::ProcessConfirmation.call(
      event_registration: @event_registration,
      person: @event_registration.registrant,
      create_user: params[:create_user] == "1",
      send_invite: params[:send_invite] == "1",
      send_confirmation_email: params[:send_confirmation_email] == "1",
      send_admin_fyi: params[:send_admin_fyi] == "1",
      current_user: current_user
    )

    case params[:return_to]
    when "registrants" then redirect_to registrants_event_path(@event_registration.event), notice: result.summary
    when "index" then redirect_to event_registrations_path, notice: result.summary
    else redirect_to registration_ticket_path(@event_registration.slug), notice: result.summary
    end
  end

  def link_organization
    @event_registration = EventRegistration.includes(:event, :organizations, registrant: :form_submissions).find(params[:id])
    authorize! @event_registration, to: :link_organization?
    @person = @event_registration.registrant
    @linked_organizations = @event_registration.organizations.order(:name)
    # The registrant's global affiliations, keyed by org, so the editor can show
    # whether each linked org is also an active/inactive affiliation (removing a
    # link here leaves the affiliation untouched).
    @affiliations_by_org = @person.affiliations.group_by(&:organization_id)
    # Every registration-form submission and the org/title the registrant entered
    # on each. Normally there's one, but a registrant can have more (legacy or
    # duplicate data), so we surface them all rather than silently picking one.
    @submitted_entries = registration_submission_entries(@event_registration)
    @form_submission = @submitted_entries.first&.fetch(:submission)
    # The "primary" submitted org/title — the first submission that named an org
    # (else the first submission) — drives the suggested-match and comparison logic.
    primary = @submitted_entries.find { |entry| entry[:org_name].present? } || @submitted_entries.first
    @submitted_org_name = primary && primary[:org_name]
    @submitted_position = primary && primary[:position]
    # Each distinct submitted org name that isn't already in the database gets its
    # own "Create and link" row, so every typed-but-missing org can be resolved.
    submitted_names = @submitted_entries.filter_map { |entry| entry[:org_name].presence&.strip }.uniq { |name| name.downcase }
    existing_names = submitted_names.any? ?
      Organization.where("LOWER(name) IN (?)", submitted_names.map(&:downcase)).pluck(Arel.sql("LOWER(name)")).map(&:to_s).to_set :
      Set.new
    @creatable_org_names = submitted_names.reject { |name| existing_names.include?(name.downcase) }
    @potential_matches = if @submitted_org_name.present?
      Organization.remote_search(@submitted_org_name).where.not(id: @linked_organizations.ids).limit(10)
    else
      Organization.none
    end
    # Per linked org, for the two persistent notes on each card: the submitted
    # answers that differ from what's saved (and so weren't applied), and what the
    # form did write onto an org that already existed. An org no submission
    # describes gets neither.
    linked_count = @linked_organizations.size
    @profile_conflicts_by_org = @linked_organizations.index_with do |org|
      profile_diff_for(org, linked_count: linked_count)
    end
    @autofill_by_org = @event_registration.event_registration_organizations
      .index_by(&:organization_id)
      .transform_values(&:form_autofill_changes)
  end

  def select_organization
    @event_registration = EventRegistration.find(params[:id])
    authorize! @event_registration, to: :select_organization?
    return deny_locked_org_edit if @event_registration.editing_locked?
    @person = @event_registration.registrant
    organization = Organization.find_by(id: params[:organization_id])
    if organization.nil?
      redirect_to link_organization_event_registration_path(@event_registration, return_to: params[:return_to].presence), alert: "Choose an organization to link."
      return
    end

    notice = link_and_report(organization, verb: "linked", record_fills: true)

    redirect_to link_organization_event_registration_path(@event_registration, return_to: params[:return_to].presence), notice: notice
  end

  def create_organization
    @event_registration = EventRegistration.find(params[:id])
    authorize! @event_registration, to: :create_organization?
    return deny_locked_org_edit if @event_registration.editing_locked?
    @person = @event_registration.registrant
    # Build the org from a name the registrant actually typed on the form, so the
    # button can't be used to create an arbitrary org — it only resolves a pending
    # submitted name. A specific name is passed when there are several submissions;
    # otherwise default to the first submitted name.
    submitted_names = submitted_organization_names(@event_registration)
    requested = params[:organization_name].presence
    name = requested ? submitted_names.find { |submitted| submitted.casecmp?(requested) } : submitted_names.first
    if name.blank?
      redirect_to link_organization_event_registration_path(@event_registration, return_to: params[:return_to].presence), alert: "No submitted organization name to create from."
      return
    end

    # Reuse an existing org with that name rather than creating a duplicate.
    existing = Organization.where("LOWER(name) = ?", name.strip.downcase).first
    organization = existing || Organization.create!(name: name.strip, organization_status: OrganizationStatus.find_by(name: "Active"))

    # Only an org that already existed gets the persistent "filled from the form"
    # note — on one we just created from the submission, everything came from the
    # form, so there's nothing to flag as changed.
    notice = link_and_report(organization, verb: existing ? "linked" : "created and linked", record_fills: existing.present?)

    redirect_to link_organization_event_registration_path(@event_registration, return_to: params[:return_to].presence), notice: notice
  end

  def unlink_organization
    @event_registration = EventRegistration.find(params[:id])
    authorize! @event_registration, to: :unlink_organization?
    return deny_locked_org_edit if @event_registration.editing_locked?
    organization = Organization.find(params[:organization_id])

    # Intentional UX choice: "Unlink" only removes the org from this registration and
    # deliberately leaves the person's global Affiliation intact. Affiliations are managed
    # on the Person record, not here — the Unlink button's confirm dialog warns about this.
    @event_registration.event_registration_organizations.where(organization_id: organization.id).destroy_all

    redirect_to link_organization_event_registration_path(@event_registration, return_to: params[:return_to].presence), notice: "#{organization.name} unlinked from this registration."
  end

  def destroy
    authorize! @event_registration
    event = @event_registration.event
    if !@event_registration.deletable?
      flash[:alert] = "This registration can't be deleted because it has financial records (payments, scholarships, or the like) or attendance on record."
    elsif @event_registration.continuing_education_registrations.any? { |ce| ce.allocations.exists? }
      # Deleting the registration would cascade away a paid CE registration (and its
      # allocations); make the admin revert the payment first.
      flash[:alert] = "Can't delete this registration while its CE registration has payments — revert the payment first."
    elsif @event_registration.destroy
      flash[:notice] = "Registration deleted."
    else
      flash[:alert] = @event_registration.errors.full_messages.to_sentence
    end

    case params[:return_to]
    when "registrants" then redirect_to registrants_event_path(event)
    when "onboarding" then redirect_to onboarding_event_path(event)
    when "attendees" then redirect_to attendees_events_path
    when "roster" then redirect_to roster_event_path(event)
    when "recipients", "recipient_card" then redirect_to recipients_event_path(event)
    else redirect_to event_registrations_path
    end
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @events =
      Event.where(published: true)
           .or(Event.where(id: @event_registration.event_id))
           .distinct
           .order(start_date: :desc)

    if @event_registration.event_id.present?
      @exclude_registrant_ids = @event_registration.event.event_registrations.pluck(:registrant_id).join(",")
    end
  end

  private

  def redirect_after_failed_create(alert)
    case params[:return_to]
    when "registrants" then redirect_to registrants_event_path(@event_registration.event), alert: alert
    else redirect_to event_registrations_path, alert: alert
    end
  end

  def set_event_registration
    @event_registration = EventRegistration.includes({ registrant: [ :user, { affiliations: :organization } ] }, { event: [ :location, :event_forms ] }, :organizations, comments: [ :created_by, :updated_by ]).find(params[:id])
  end

  # Back to the report in read mode, scrolled to the day cell that was edited, keeping
  # whichever view the admin had open. `reopen:` puts that cell back into edit mode.
  def attendance_report_path(date, reopen: false)
    # `row` names the reported line the editor was opened on — a registrant reported
    # once per CE licence has one cell per licence, and only that one should reopen.
    cell = helpers.attendance_cell_id(params[:row].presence || @event_registration.id, date)
    attendance_event_path(@event_registration.event,
      ce: params[:ce].presence, group: params[:group].presence, return_to: params[:return_to].presence,
      edit: (cell if reopen), anchor: cell)
  end

  # Events a registrant can be transferred into: events of the same format as
  # the one they're leaving — an on-demand event only transfers to another
  # on-demand event, and a scheduled (non-on-demand) event only to another
  # scheduled event — whether or not they're published, excluding the source
  # event, most recent first.
  def transfer_destination_events
    Event.where(on_demand: @event_registration.event.on_demand)
         .where.not(id: @event_registration.event_id)
         .order(start_date: :desc)
  end

  # Creates the audited completion row for a checklist step (recording who/when),
  # or removes it — so an unchecked step leaves no trace.
  def toggle_checklist_step(step, completed)
    completion = @event_registration.checklist_completions.find_by(step: step)
    if completed && completion.nil?
      @event_registration.checklist_completions.create(step: step, completed_by: current_user, completed_at: Time.current)
    elsif !completed && completion
      completion.destroy
    end
  end

  # Strong parameters
  def event_registration_params
    params.require(:event_registration).permit(
      :event_id, :registrant_id, :status,
      :scholarship_requested,
      :shoutout,
      :intends_to_pay,
      :someone_else_will_pay,
      :expected_payment_method,
      :fee_note,
      *EventRegistration::DAY_FIELDS,
      organization_ids: [],
      registrant_attributes: [ :id, :shoutout_text ],
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      notifications_attributes: [ :id, :channel, :sender_id, :email_subject, :email_body_text, :direction, :responded, :noticeable_type, :noticeable_id, :_destroy ]
    )
  end

  def event_registration_update_params
    return locked_editable_params if @event_registration.editing_locked?
    if allowed_to?(:manage?, with: EventRegistrationPolicy)
      event_registration_params
    else
      params.require(:event_registration).permit(:status)
    end
  end

  # A transferred-out reg keeps only comments and communications editable (#1944).
  LOCKED_EDITABLE_KEYS = %w[ comments_attributes notifications_attributes ].freeze

  def locked_editable_params
    params.fetch(:event_registration, {}).permit(
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      notifications_attributes: [ :id, :channel, :sender_id, :email_subject, :email_body_text, :direction, :responded, :noticeable_type, :noticeable_id, :_destroy ]
    )
  end

  # Warn rather than silently swallow: if a locked reg's form somehow submits fields
  # beyond comments/communications, tell the admin they were ignored.
  def warn_if_locked_fields_submitted
    return unless @event_registration.editing_locked?
    ignored = params.fetch(:event_registration, {}).keys.map(&:to_s) - LOCKED_EDITABLE_KEYS
    return if ignored.empty?
    flash[:alert] = "This registration was transferred out and is locked — only comments and communications were saved. Undo the transfer to edit anything else."
  end

  def block_locked_registration
    return unless @event_registration.editing_locked?
    redirect_to(request.referer.presence || edit_event_registration_path(@event_registration),
      alert: "#{@event_registration.registrant&.full_name} was transferred out — this registration is locked. Undo the transfer to make changes.",
      status: :see_other)
  end

  def deny_locked_org_edit
    redirect_to link_organization_event_registration_path(@event_registration, return_to: params[:return_to].presence),
      alert: "This registration was transferred out and is locked. Undo the transfer to change linked organizations."
  end

  def csv_export(registrations)
    CSV.generate(headers: true) do |csv|
      csv << [ "First name", "Last name", "Email", "Phone", "Event", "Status", "Scholarship", "Scholarship completed", "Payment status", "Intends to pay", "Payment total", "CE status", "CE paid", "CE due" ]
      registrations.find_each do |er|
        r = er.registrant
        e = er.event
        total_cents = er.allocations_sum
        cost_required = e&.cost_cents.to_i > 0
        csv << [
          r&.first_name.to_s,
          r&.last_name.to_s,
          r&.preferred_email.to_s,
          r&.phone_number.to_s,
          e&.title.to_s,
          er.attendance_status_report_label,
          er.scholarships.any? ? "Yes" : "No",
          er.scholarships.any?(&:tasks_completed?) ? "Yes" : "No",
          cost_required ? er.payment_status_label : "",
          er.intends_to_pay? ? "Yes" : "No",
          csv_dollars(total_cents),
          er.ce_registered? ? er.ce_status_label.to_s : "",
          csv_dollars(er.ce_amount_paid_cents),
          csv_dollars(er.ce_amount_due_cents)
        ]
      end
    end
  end

  # Each registration-form submission with the org name and position the registrant
  # entered on it: [{ submission:, org_name:, position: }], oldest first. Memoized:
  # the linking actions ask for these entries half a dozen times per request
  # (profile, address, position, then again to build the notice).
  def registration_submission_entries(registration)
    @registration_submission_entries ||= {}
    @registration_submission_entries[registration.id] ||= build_registration_submission_entries(registration)
  end

  def build_registration_submission_entries(registration)
    form = registration.event.registration_form
    return [] unless form

    organization_identifiers = %w[
      organization_name organization_position organization_website organization_type
      organization_street organization_city organization_state organization_zip organization_country
    ]
    field_ids = form.form_fields
      .where(field_identifier: organization_identifiers)
      .pluck(:field_identifier, :id).to_h

    entries = registration.registrant.form_submissions
      .where(form: form)
      .order(:created_at)
      .includes(:form_answers)
      .map do |submission|
        answers = submission.form_answers.index_by(&:form_field_id)
        answer = ->(identifier) do
          id = field_ids[identifier]
          id && answers[id]&.submitted_answer
        end
        {
          submission: submission,
          org_name: answer.call("organization_name"),
          position: answer.call("organization_position"),
          website: answer.call("organization_website"),
          organization_type: answer.call("organization_type"),
          address: {
            street_address: answer.call("organization_street"),
            city: answer.call("organization_city"),
            state: answer.call("organization_state"),
            zip_code: answer.call("organization_zip"),
            country: answer.call("organization_country")
          }
        }
      end

    # Attach the matching DB org (if any) for each submitted name, so the view can
    # show its city/state next to the answer. Batched to avoid a query per entry.
    names = entries.filter_map { |entry| entry[:org_name].presence&.strip&.downcase }.uniq
    orgs_by_name = names.any? ?
      Organization.where("LOWER(name) IN (?)", names).index_by { |org| org.name.to_s.downcase } :
      {}
    entries.each { |entry| entry[:organization] = entry[:org_name].present? ? orgs_by_name[entry[:org_name].strip.downcase] : nil }
    entries
  end

  # Distinct, non-blank org names the registrant typed across their registration-form
  # submissions (case-insensitive dedupe, first spelling wins).
  def submitted_organization_names(registration)
    registration_submission_entries(registration)
      .filter_map { |entry| entry[:org_name].presence&.strip }
      .uniq { |name| name.downcase }
  end

  # The submission entry whose answers describe `organization`: the one pinned on
  # the link when it was made, else the one whose typed org name matches, else —
  # only when the pairing is unambiguous, i.e. a single submission and a single
  # linked org — that sole entry, which covers a registrant who named no org and an
  # admin resolving a typo'd "Acme Inc" to the saved "Acme Corporation". Nil
  # otherwise: an extra org an admin linked by hand isn't the one the registrant
  # wrote about, so none of the submitted answers apply to it.
  # Memoized per org: a linking action asks for the entry and then again for the
  # conflict note, and the fallback counts the registration's linked orgs.
  def submission_entry_for(registration, organization, linked_count: nil)
    @submission_entries_by_org ||= {}
    return @submission_entries_by_org[organization.id] if @submission_entries_by_org.key?(organization.id)

    @submission_entries_by_org[organization.id] = find_submission_entry(registration, organization, linked_count)
  end

  # Every submission entry whose answers describe `organization` (not just the
  # first): the pinned one, plus every one whose typed org name matches. Falls
  # back to the sole entry only when the pairing is unambiguous (one submission,
  # one linked org) — the same rule as find_submission_entry. Used to back-apply
  # the metadata link to all of a registrant's submissions that named this org.
  def submission_entries_for(registration, organization)
    entries = registration_submission_entries(registration)
    pinned = pinned_submission_ids(registration)[organization.id]
    matches = entries.select do |entry|
      entry[:submission].id == pinned ||
        (entry[:org_name].present? && entry[:org_name].strip.casecmp?(organization.name.to_s.strip))
    end
    return matches if matches.any?
    return [] unless entries.one?

    registration.organizations.count == 1 ? entries : []
  end

  def find_submission_entry(registration, organization, linked_count)
    entries = registration_submission_entries(registration)
    # The pinned submission wins: the name and sole-org rules below are re-derived
    # on every request, so an org linked under a name the registrant didn't type
    # would otherwise lose its answers (and its discrepancy note) the moment a
    # second org is linked.
    pinned = pinned_submission_ids(registration)[organization.id]
    match = pinned && entries.find { |entry| entry[:submission].id == pinned }
    match ||= entries.find { |entry| entry[:org_name].present? && entry[:org_name].strip.casecmp?(organization.name.to_s.strip) }
    return match if match
    return unless entries.one?

    entries.first if (linked_count || registration.organizations.count) == 1
  end

  # The submission pinned on each of this registration's org links, by org id.
  # Loaded once: the linking page asks for every linked org.
  def pinned_submission_ids(registration)
    @pinned_submission_ids ||= registration.event_registration_organizations
      .pluck(:organization_id, :form_submission_id).to_h
  end

  # The submitted answers for this org that differ from a value already on it, for
  # the linking flash and the per-card note. Empty when no submission describes it,
  # so one org's answers are never reported against another.
  def profile_diff_for(organization, linked_count: nil)
    entry = submission_entry_for(@event_registration, organization, linked_count: linked_count)
    return [] unless entry

    OrganizationServices::ProfileDiff.call(
      organization: organization,
      website: entry[:website],
      organization_type: entry[:organization_type],
      address: entry[:address] || {}
    )
  end

  # Link the org to the registration, fill what it's missing from the submission
  # that names it (blanks only — curated values are kept and reported as
  # discrepancies instead), and build the flash notice — via the linking core
  # shared with the form submission editor. The link row is created first so
  # submission_entry_for counts it when deciding whether the pairing is
  # unambiguous. `record_fills` keeps a persistent note of what the form changed.
  def link_and_report(organization, verb:, record_fills:)
    link = @event_registration.event_registration_organizations.find_or_create_by!(organization: organization)
    entry = submission_entry_for(@event_registration, organization)
    # Attribute the org writes below to the submission that named it, so linking an
    # org that wasn't a clean match shows up in that submission's changes audit.
    Current.form_submission_id = entry[:submission].id if entry

    result = OrganizationServices::LinkSubmittedOrganization.call(
      person: @event_registration.registrant,
      organization: organization,
      entry: entry,
      scenario: event_linking_scenario(@event_registration.event),
      training_date: @event_registration.event.start_date,
      event_registration: @event_registration
    )

    # Pin the pairing even when nothing was filled — an org whose every answer
    # conflicts fills nothing, and that's exactly the one whose note has to survive.
    link.record_form_submission(entry[:submission]) if entry
    # Back-apply the resolution onto every submission this org describes, so each
    # reads as linked in its own editor too (even under a name mismatch). A
    # registrant can have several submissions naming the same org; the pin and
    # profile note above stay on the single primary entry, but the metadata link
    # fans out to all of them.
    submission_entries_for(@event_registration, organization).each do |describing|
      describing[:submission].link_organization!(organization.id)
    end
    link.record_autofill(result.saved) if record_fills

    warning = result.warning(organization: organization)
    flash[:warning] = warning if warning
    result.notice(organization: organization, verb: verb)
  end

  # Which linking scenario this registration's event maps to (ADR-0002 D2): an
  # on-demand facilitator training shares the agreement path's "on_demand"
  # scenario, a scheduled one is "facilitator_training", and anything else
  # confers no Facilitator affiliation. Event scenarios never end-date.
  def event_linking_scenario(event)
    return "non_facilitator_training" unless event.facilitator_training

    event.on_demand ? "on_demand" : "facilitator_training"
  end
end
