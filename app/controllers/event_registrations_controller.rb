class EventRegistrationsController < ApplicationController
  require "csv"

  before_action :set_event_registration, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(EventRegistration.all)
    filtered = base_scope.search_by_params(params)
    @event_registrations_count = filtered.size
    @event_registrations = filtered.includes(:registrant, :event).paginate(page: params[:page], per_page: per_page)

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
  end

  def new
    @event_registration = EventRegistration.new
    authorize! @event_registration
    set_form_variables
  end

  def edit
    authorize! @event_registration
    set_form_variables
  end

  def create
    @event_registration = EventRegistration.new(event_registration_params)
    authorize! @event_registration

    if @event_registration.save
      NotificationServices::CreateNotification.call(
        noticeable: @event_registration,
        kind: "event_registration_confirmation",
        recipient_role: :person,
        recipient_email: current_user.email,
        notification_type: 0)
      NotificationServices::CreateNotification.call(
        noticeable: @event_registration,
        kind: "event_registration_confirmation_fyi",
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0)

      respond_to do |format|
        format.html {
          redirect_to event_registrations_path,
            notice: "Registration created."
        }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to event_registrations_path,
            alert: @event_registration.errors.full_messages.to_sentence
        }
      end
    end
  end

  def update
    authorize! @event_registration
    if @event_registration.update(event_registration_params)
      redirect_to event_registrations_path, notice: "Registration was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @event_registration
    if @event_registration.destroy
      flash[:notice] = "Registration deleted."

    else
      flash[:alert] = @event_registration.errors.full_messages.to_sentence
    end
    redirect_to event_registrations_path
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @events =
      Event.where(published: true)
           .or(Event.where(id: @event_registration.event_id))
           .distinct
           .order(start_date: :desc)
    @registrants = User.active.includes(:person).order("people.first_name, people.last_name")
  end

  private

  def set_event_registration
    @event_registration = EventRegistration.find(params[:id])
  end

  # Strong parameters
  def event_registration_params
    params.require(:event_registration).permit(
      :event_id, :registrant_id
    )
  end

  def csv_export(registrations)
    CSV.generate(headers: true) do |csv|
      csv << [ "First name", "Last name", "Email", "Event" ]
      registrations.find_each do |er|
        r = er.registrant
        e = er.event
        csv << [
          r&.first_name.to_s,
          r&.last_name.to_s,
          r&.email.to_s,
          e&.title.to_s
        ]
      end
    end
  end
end
