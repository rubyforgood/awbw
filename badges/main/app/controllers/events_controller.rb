class EventsController < ApplicationController
  include AhoyTracking, TagAssignable
  skip_before_action :authenticate_user!, only: [ :index, :show, :staff ]
  skip_before_action :verify_authenticity_token, only: [ :preview ]
  before_action :set_event, only: %i[ show edit update destroy preview dashboard sample_ticket background registrants onboarding staff edit_staff update_staff recipients bulk_payments preview_reminder confirm_reminder send_reminder copy_registration_form allocate_bulk_payment create_bulk_payment ]

  def index
    authorize!
    base_scope = authorized_scope(Event.all)
    base_scope = base_scope.staffed_by(current_user.person) if params[:staffed_by_me].present? && current_user&.person
    @events  = base_scope.search_by_params(params).order(start_date: :desc)
  end

  def show
    authorize! @event
    @event = @event.decorate
    track_view(@event)
  end

  # Cross-event revenue report across every paid event (those that charge a
  # registration fee). The KPI strip leads with the year of the event the CEO
  # navigated from (when arriving from a dashboard), otherwise the current year.
  def revenue
    authorize!
    @events = Event.paid.order(start_date: :desc).map(&:decorate)
    origin_event = Event.find_by(id: params[:event_id]) if params[:event_id].present?
    @report = EventRevenueReport.new(@events, featured_year: origin_event&.start_date&.year)
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

    @show_all_options = params[:options] == "all"
    registrant = Person.new(first_name: "Sample", last_name: "Registrant")
    @event_registration = @event.event_registrations.new(
      registrant: registrant,
      slug: "sample",
      status: "registered",
      intends_to_pay: true,
      w9_requested: @show_all_options,
      invoice_requested: @show_all_options,
      scholarship_requested: @show_all_options,
      shoutout: @show_all_options,
      created_at: Time.current
    )
    build_sample_ce_registration if @show_all_options
  end

  def background
    authorize! @event, to: :background?
    @event = @event.decorate
    @dashboard = EventDashboard.new(@event)
  end

  def registrants
    authorize! @event, to: :registrants?
    @event = @event.decorate
    scope = @event.event_registrations
      .includes(:comments, :organizations, :allocations, :scholarships, { continuing_education_registrations: [ :professional_license, :allocations ] }, registrant: [ :user, :contact_methods, { avatar_attachment: :blob }, { affiliations: :organization } ])
      .joins(:registrant)
    scope = scope.keyword(params[:keyword]) if params[:keyword].present?
    scope = scope.payment_status(params[:payment_status]) if params[:payment_status].present?
    scope = scope.scholarship_status(params[:scholarship]) if params[:scholarship].present?
    scope = scope.ce_status(params[:ce_status]) if params[:ce_status].present?
    scope = scope.comment_status(params[:comment_status]) if params[:comment_status].present?
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
      .includes(:checklist_completions, :organizations, :allocations, :scholarships, :comments, { continuing_education_registrations: :professional_license }, registrant: [ :user, { affiliations: :organization } ])
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
      .includes(person: [ :sectors, { avatar_attachment: :blob }, { affiliations: :organization } ])
      .ordered_by_name
  end

  def edit_staff
    authorize! @event, to: :edit_staff?
    @event.event_staffs.build if @event.event_staffs.empty?
  end

  def update_staff
    authorize! @event, to: :update_staff?

    if @event.update(event_staff_params)
      redirect_to staff_event_path(@event), notice: "Event staff updated."
    else
      render :edit_staff, status: :unprocessable_content
    end
  end

  def recipients
    authorize! @event, to: :recipients?
    @event = @event.decorate
    @dashboard = EventDashboard.new(@event)
  end

  def bulk_payments
    authorize! @event

    @event = @event.decorate
    # Shared across every card so attendee matching and allocated totals don't
    # re-query per registration per card.
    @event_registrations = @event.event_registrations.active.includes(:registrant)
    @submissions = @event.form_submissions
                         .where(role: "bulk_payment")
                         .includes(:person, form_answers: :form_field, payment: :allocations)
                         .order(created_at: :desc)
    @allocated_by_registration = allocated_cents_by_registration(@event_registrations)
  end

  def allocate_bulk_payment
    authorize! @event
    @event = @event.decorate
    payment = Payment.find(params[:payment_id])
    event_registration = EventRegistration.find_by(id: params[:event_registration_id])
    unless event_registration
      flash.now[:alert] = "Please select a registrant"
      assign_allocation_card_data(payment)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bulk_payments_event_path(@event), alert: "Please select a registrant" }
      end
      return
    end
    amount_cents = (params[:amount_dollars].to_d * 100).to_i

    if amount_cents <= 0
      flash.now[:alert] = "Amount must be greater than $0.00"
    elsif amount_cents > (payment.amount_cents_remaining || 0)
      flash.now[:alert] = "Amount exceeds remaining balance"
    else
      allocation = Allocation.new(source: payment, allocatable: event_registration, amount: amount_cents)
      if allocation.save
        flash.now[:notice] = "Allocation successful"
      else
        flash.now[:alert] = allocation.errors.full_messages.to_sentence
      end
    end

    assign_allocation_card_data(payment)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bulk_payments_event_path(@event), notice: flash.now[:alert] || "Allocation successful" }
    end
  end

  def create_bulk_payment
    authorize! @event
    @event = @event.decorate
    @event_registrations = @event.event_registrations.active.includes(:registrant)
    @allocated_by_registration = allocated_cents_by_registration(@event_registrations)

    submission = @event.form_submissions.find(params[:submission_id])
    payment_type = params[:payment_type]

    unless %w[CashPayment CheckPayment].include?(payment_type)
      flash.now[:alert] = "Invalid payment type"
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bulk_payments_event_path(@event), alert: "Invalid payment type" }
      end
      return
    end

    payment = submission.build_payment(
      amount_cents: (params[:amount_dollars].to_d * 100).to_i,
      currency: params[:currency].presence || "usd",
      type: payment_type,
      check_number: params[:check_number].presence,
      memo: params[:memo].presence
    )
    payment.payer_sgid = params[:payer_sgid]
    payment.additional_designation_sgid = params[:additional_designation_sgid]

    if payment.save
      @payment = payment
      @submission = submission.decorate
      flash.now[:notice] = "Payment recorded"
    else
      flash.now[:alert] = payment.errors.full_messages.to_sentence
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bulk_payments_event_path(@event), notice: flash.now[:alert] || "Payment recorded" }
    end
  end

  def preview_reminder
    authorize! @event
    @event = @event.decorate
    @ce_eligible = @event.ce_eligible?
    @event_registrations = @event.event_registrations
      .includes(
        :event, :organizations, :comments,
        { scholarships: { grant: :donor } },
        registrant: [ :user, :contact_methods ]
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
        custom_message: custom_message.presence,
        custom_subject: custom_subject.presence
      )
    end

    # One admin summary for the whole batch: count, roster, and a copy of what
    # was sent. Roster passed as plain "Name <email>" labels so the delivery job
    # needs no record lookups.
    recipient_labels = registrations.map { |r| "#{r.registrant.full_name} <#{r.registrant.preferred_email}>" }
    EventMailer.event_registration_reminder_fyi(@event, recipient_labels, custom_message: custom_message.presence).deliver_later

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

  # Build (unsaved) a CE registration on the sample ticket so the "Show all
  # options" preview renders a populated CE card. Mirrors a complete, paid-looking
  # CE record without touching the database.
  def build_sample_ce_registration
    license = ProfessionalLicense.new(person: @event_registration.registrant, number: "SAMPLE-12345")
    @event_registration.continuing_education_registrations.build(
      professional_license: license,
      hours: @event.ce_hours_offered || 6,
      cost_cents: @event.ce_hours_cost_cents || 15_000
    )
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

  # Reloads the payment and the data its bulk payment card needs, so the
  # allocate turbo stream can re-render the whole card with fresh due/allocated
  # totals and re-evaluate whether each registration is now paid in full.
  def assign_allocation_card_data(payment)
    @payment = payment.reload
    @submission = @payment.form_submission
    @event_registrations = @event.event_registrations.active.includes(:registrant)
    @allocated_by_registration = allocated_cents_by_registration(@event_registrations)
  end

  # Allocated cents per registration id, fetched in one grouped query so the
  # bulk payment cards read totals from a hash instead of querying per row.
  def allocated_cents_by_registration(registrations)
    Allocation
      .where(allocatable_type: "EventRegistration", allocatable_id: registrations.ids)
      .group(:allocatable_id)
      .sum(:amount)
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
    headers = [ "First name", "Last name", "Email", "Phone", "Organization", "Scholarship recipient", "Scholarship tasks completed", "Payment status", "Intends to pay", "Payment total" ]
    headers << "CE status" if include_ce
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
    payment_total = total_cents.positive? ? format("%.2f", total_cents / 100.0) : ""
    payment_status = cost_required ? registration.payment_status_label : ""
    row = [
      person.first_name,
      person.last_name,
      person.preferred_email.presence || "",
      person.phone_number.presence || "",
      org_names.presence || "",
      registration.scholarships.any? ? "Yes" : "No",
      registration.scholarships.completed.any? ? "Yes" : "No",
      payment_status,
      registration.intends_to_pay? ? "Yes" : "No",
      payment_total
    ]
    row << registration.ce_status_label.to_s if include_ce
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
    headers += [ "CE requested", "CE hours", "CE amount", "CE license" ] if include_ce
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
    row << (registration.discount_sum.positive? ? helpers.dollars_from_cents(registration.discount_sum) : "")
    row << (scholarship ? helpers.dollars_from_cents(scholarship.amount_cents) : "")
    row << (scholarship ? (scholarship.grant&.name.presence || "Unfunded") : "")
    row << onboarding_scholarship_tasks_csv(registration)
    if include_ce
      ce_hours = registration.ce_hours_total
      row << (registration.ce_registered? ? "Yes" : "No")
      row << (ce_hours.positive? ? helpers.plain_number(ce_hours) : "")
      row << (registration.ce_amount_owed_cents.positive? ? helpers.dollars_from_cents(registration.ce_amount_owed_cents) : "")
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
