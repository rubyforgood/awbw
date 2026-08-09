class EventRegistrationsController < ApplicationController
  require "csv"

  # show redirects to slug URL; kept for backwards compatibility
  before_action :set_event_registration, only: [ :show, :edit, :update, :destroy, :update_onboarding, :toggle_certificate_issued ]

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
    @event_registration.assign_attributes(event_registration_update_params)
    @event_registration.comments.select(&:new_record?).each { |c| c.created_by = current_user; c.updated_by = current_user }
    @event_registration.comments.select { |c| c.persisted? && c.body_changed? }.each { |c| c.updated_by = current_user }

    # Inline-logged notifications are addressed to the registrant.
    recipient_email = @event_registration.registrant&.preferred_email.presence || "n/a"
    @event_registration.notifications.select(&:new_record?).each { |n| n.recipient_email = recipient_email }

    if @event_registration.save
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
          # Two ways back to the recipients page: the shout-outs section (the
          # feature-a-shout-out flow) or the recipient's own card (their name).
          when "recipients" then redirect_to recipients_event_path(@event_registration.event, anchor: "shout-outs"), notice: notice, status: :see_other
          when "recipient_card" then redirect_to helpers.recipients_event_card_path(@event_registration.event, @event_registration.slug), notice: notice, status: :see_other
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
  end

  def select_organization
    @event_registration = EventRegistration.find(params[:id])
    authorize! @event_registration, to: :select_organization?
    @person = @event_registration.registrant
    organization = Organization.find(params[:organization_id])

    link_affiliations_for(@event_registration, organization)

    @event_registration.event_registration_organizations
      .find_or_create_by!(organization: organization)

    redirect_to link_organization_event_registration_path(@event_registration, return_to: params[:return_to].presence), notice: "#{organization.name} linked."
  end

  def create_organization
    @event_registration = EventRegistration.find(params[:id])
    authorize! @event_registration, to: :create_organization?
    @person = @event_registration.registrant
    # Build the org from a name the registrant actually typed on the form, so the
    # button can't be used to create an arbitrary org — it only resolves a pending
    # submitted name. A specific name is passed when there are several submissions;
    # otherwise default to the first submitted name.
    submitted_names = submitted_agency_names(@event_registration)
    requested = params[:organization_name].presence
    name = requested ? submitted_names.find { |submitted| submitted.casecmp?(requested) } : submitted_names.first
    if name.blank?
      redirect_to link_organization_event_registration_path(@event_registration, return_to: params[:return_to].presence), alert: "No submitted organization name to create from."
      return
    end

    # Reuse an existing org with that name rather than creating a duplicate.
    existing = Organization.where("LOWER(name) = ?", name.strip.downcase).first
    organization = existing || Organization.create!(name: name.strip, organization_status: OrganizationStatus.find_by(name: "Active"))

    link_affiliations_for(@event_registration, organization)
    @event_registration.event_registration_organizations.find_or_create_by!(organization: organization)

    notice = existing ? "#{organization.name} linked." : "#{organization.name} created and linked."
    redirect_to link_organization_event_registration_path(@event_registration, return_to: params[:return_to].presence), notice: notice
  end

  def unlink_organization
    @event_registration = EventRegistration.find(params[:id])
    authorize! @event_registration, to: :unlink_organization?
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
    when "recipients" then redirect_to recipients_event_path(event)
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
      notifications_attributes: [ :id, :channel, :sender_id, :email_subject, :email_body_text, :noticeable_type, :noticeable_id, :_destroy ]
    )
  end

  def event_registration_update_params
    if allowed_to?(:manage?, with: EventRegistrationPolicy)
      event_registration_params
    else
      params.require(:event_registration).permit(:status)
    end
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
          er.attendance_status_label,
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
  # entered on it: [{ submission:, org_name:, position: }], oldest first.
  def registration_submission_entries(registration)
    form = registration.event.registration_form
    return [] unless form

    field_ids = form.form_fields
      .where(field_identifier: %w[agency_name agency_position agency_street agency_city agency_state agency_zip agency_country])
      .pluck(:field_identifier, :id).to_h

    entries = registration.registrant.form_submissions
      .where(form: form)
      .order(:created_at)
      .includes(:form_answers)
      .map do |submission|
        answers = submission.form_answers.index_by(&:form_field_id)
        answer = ->(identifier) { (id = field_ids[identifier]) && answers[id]&.submitted_answer }
        {
          submission: submission,
          org_name: answer.call("agency_name"),
          position: answer.call("agency_position"),
          address: {
            street_address: answer.call("agency_street"),
            city: answer.call("agency_city"),
            state: answer.call("agency_state"),
            zip_code: answer.call("agency_zip"),
            country: answer.call("agency_country")
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
  def submitted_agency_names(registration)
    registration_submission_entries(registration)
      .filter_map { |entry| entry[:org_name].presence&.strip }
      .uniq { |name| name.downcase }
  end

  # The job title/position the registrant typed for their organization on the
  # registration form. Uses the same "primary" submission as link_organization
  # (the first submission that named an org, else the first), so the title applied
  # when linking matches what the editor shows.
  def submitted_position(registration)
    entries = registration_submission_entries(registration)
    primary = entries.find { |entry| entry[:org_name].present? } || entries.first
    primary && primary[:position]
  end

  # The org address fields the registrant typed on the same "primary" submission
  # used for the org name/position, as attrs for OrganizationServices::UpsertAddress.
  def submitted_agency_address(registration)
    entries = registration_submission_entries(registration)
    primary = entries.find { |entry| entry[:org_name].present? } || entries.first
    primary && primary[:address] || {}
  end

  # Upsert the linked org's work address from the registrant's submission and
  # create the job + facilitator affiliations linked to it. Shared by the
  # select-existing and create-new org-linking actions.
  def link_affiliations_for(registration, organization)
    organization_address = OrganizationServices::UpsertAddress.call(
      organization: organization,
      **submitted_agency_address(registration)
    )

    AffiliationServices::CreateFromRegistration.call(
      person: registration.registrant,
      organization: organization,
      job_title: submitted_position(registration),
      training_date: registration.event.start_date,
      organization_address: organization_address
    )
  end
end
