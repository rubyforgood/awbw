class EventRegistrationsController < ApplicationController
  require "csv"

  # show redirects to slug URL; kept for backwards compatibility
  before_action :set_event_registration, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(EventRegistration.all)
    filtered = base_scope.search_by_params(params)
    @event_registrations_count = filtered.size
    @event_registrations = filtered.includes(registrant: [ :user, { avatar_attachment: :blob } ], event: :event_forms).paginate(page: params[:page], per_page: per_page)
    @events = Event.order(start_date: :desc)
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
      respond_to do |format|
        format.html {
          case params[:return_to]
          when "registrants" then redirect_to registrants_event_path(@event_registration.event), alert: @event_registration.errors.full_messages.to_sentence
          else redirect_to event_registrations_path, alert: @event_registration.errors.full_messages.to_sentence
          end
        }
      end
    end
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
      cleanup_unrequested_scholarship
      respond_to do |format|
        format.turbo_stream
        format.html {
          case params[:return_to]
          when "registrants" then redirect_to registrants_event_path(@event_registration.event), notice: "Registration was successfully updated.", status: :see_other
          when "index" then redirect_to event_registrations_path, notice: "Registration was successfully updated.", status: :see_other
          when "ticket" then redirect_to registration_ticket_path(@event_registration.slug), notice: "Registration was successfully updated.", status: :see_other
          else
            # No explicit origin: keep admins in the management context (the
            # roster) rather than dropping them on the public registration show.
            if allowed_to?(:manage?, with: EventRegistrationPolicy)
              redirect_to registrants_event_path(@event_registration.event), notice: "Registration was successfully updated.", status: :see_other
            else
              redirect_to registration_ticket_path(@event_registration.slug), notice: "Registration was successfully updated.", status: :see_other
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
    @event_registration = EventRegistration.includes(:event, registrant: :form_submissions).find(params[:id])
    authorize! @event_registration, to: :link_organization?
    @person = @event_registration.registrant
    @submitted_org_name = find_submitted_agency_name(@event_registration)
    @potential_matches = if @submitted_org_name.present?
      Organization.remote_search(@submitted_org_name).limit(10)
    else
      Organization.none
    end
  end

  def select_organization
    @event_registration = EventRegistration.find(params[:id])
    authorize! @event_registration, to: :select_organization?
    @person = @event_registration.registrant
    organization = Organization.find(params[:organization_id])

    Affiliation.find_or_create_by!(person: @person, organization: organization)

    @event_registration.event_registration_organizations
      .find_or_create_by!(organization: organization)

    redirect_to registrants_event_path(@event_registration.event), notice: "Organization linked successfully."
  end

  def destroy
    authorize! @event_registration
    event = @event_registration.event
    if @event_registration.destroy
      flash[:notice] = "Registration deleted."
    else
      flash[:alert] = @event_registration.errors.full_messages.to_sentence
    end

    case params[:return_to]
    when "registrants" then redirect_to registrants_event_path(event)
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

  def set_event_registration
    @event_registration = EventRegistration.includes({ registrant: [ :user, { affiliations: :organization } ] }, { event: [ :location, :event_forms ] }, :organizations, comments: [ :created_by, :updated_by ]).find(params[:id])
  end

  # When an admin unchecks "Requested" and saves, tidy up an associated
  # scholarship that was never actually awarded — i.e. an empty stub with no
  # amount and incomplete tasks. A funded or completed scholarship is left alone.
  def cleanup_unrequested_scholarship
    return unless allowed_to?(:manage?, with: EventRegistrationPolicy)
    return unless @event_registration.saved_change_to_scholarship_requested?
    return if @event_registration.scholarship_requested?

    scholarship = @event_registration.scholarships.first
    return unless scholarship && scholarship.amount_cents.to_i.zero? && !scholarship.tasks_completed?

    scholarship.destroy
  end

  # Strong parameters
  def event_registration_params
    params.require(:event_registration).permit(
      :event_id, :registrant_id, :status,
      :scholarship_requested,
      :ce_credit_requested,
      organization_ids: [],
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      notifications_attributes: [ :channel, :sender_id, :email_subject, :email_body_text, :noticeable_type, :noticeable_id ]
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
      csv << [ "First name", "Last name", "Email", "Phone", "Event", "Status", "Scholarship", "Scholarship completed", "Payment status", "Payment total" ]
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
          er.scholarships.completed.any? ? "Yes" : "No",
          cost_required ? (er.paid_in_full? ? "Paid in full" : "Not paid in full") : "",
          total_cents.positive? ? format("%.2f", total_cents / 100.0) : ""
        ]
      end
    end
  end

  def find_submitted_agency_name(registration)
    form = registration.event.registration_form
    return nil unless form

    field = form.form_fields.find_by(field_identifier: "agency_name")
    return nil unless field

    FormAnswer
      .joins(form_submission: :person)
      .find_by(
        form_submissions: { person_id: registration.registrant_id, form_id: form.id },
        form_field_id: field.id
      )&.submitted_answer
  end
end
