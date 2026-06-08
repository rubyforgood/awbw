class EventsController < ApplicationController
  include AhoyTracking, TagAssignable
  skip_before_action :authenticate_user!, only: [ :index, :show, :staff ]
  skip_before_action :verify_authenticity_token, only: [ :preview ]
  before_action :set_event, only: %i[ show edit update destroy preview dashboard background registrants staff recipients preview_reminder send_reminder copy_registration_form ]

  def index
    authorize!
    base_scope = authorized_scope(Event.all)
    @events  = base_scope.search_by_params(params).order(start_date: :desc)
  end

  def show
    authorize! @event
    @event = @event.decorate
    track_view(@event)
  end

  def new
    authorize!
    @event = Event.new.decorate
    set_form_variables
  end

  def edit
    authorize! @event
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

  def background
    authorize! @event, to: :background?
    @event = @event.decorate
    @dashboard = EventDashboard.new(@event)
  end

  def registrants
    authorize! @event, to: :registrants?
    @event = @event.decorate
    scope = @event.event_registrations
      .includes(:comments, :organizations, registrant: [ :user, :contact_methods, { avatar_attachment: :blob } ])
      .joins(:registrant)
    scope = scope.keyword(params[:keyword]) if params[:keyword].present?
    scope = scope.attendance_status(params[:attendance_status]) if params[:attendance_status].present?
    scope = scope.payment_status(params[:payment_status]) if params[:payment_status].present?
    scope = scope.scholarship_status(params[:scholarship]) if params[:scholarship].present?
    scope = scope.registrant_ids(params[:registrant_ids]) if params[:registrant_ids].present?
    scope = scope.registrant_state(params[:state]) if params[:state].present?
    scope = scope.registrant_county(params[:county]) if params[:county].present?
    scope = scope.registrant_sector(params[:sector]) if params[:sector].present?
    @event_registrations = scope.order(Arel.sql("people.first_name, people.last_name"))
    @dashboard = EventDashboard.new(@event)

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

  def staff
    authorize! @event, to: :staff?
    @event = @event.decorate
    @staff = @event.event_registrations
      .active
      .includes(registrant: [ :sectors, { avatar_attachment: :blob }, { affiliations: :organization } ])
      .joins(:registrant)
      .order(Arel.sql("people.first_name, people.last_name"))
      .map(&:registrant)
  end

  def recipients
    authorize! @event, to: :recipients?
    @event = @event.decorate
    @dashboard = EventDashboard.new(@event)
  end

  def preview_reminder
    authorize! @event
    @event = @event.decorate
    @event_registrations = @event.event_registrations
      .includes(registrant: [ :user, :contact_methods ])
      .joins(:registrant)
      .select { |r| r.registrant.preferred_email.present? }
    @sample_registration = @event_registrations.first
    @days_until_event = @event.start_date.present? ? (@event.start_date.to_date - Date.current).to_i : nil

    if @sample_registration
      mail = EventMailer.event_registration_reminder(@sample_registration, days_until_event: @days_until_event)
      @reminder_preview_html = mail.html_part&.body&.decoded
    end
  end

  def send_reminder
    authorize! @event, to: :send_reminder?
    allowed_ids = Array(params[:registration_ids]).map(&:to_i).reject(&:zero?)
    registrations = @event.event_registrations
      .where(id: allowed_ids)
      .includes(registrant: [ :user, :contact_methods ])
      .select { |r| r.registrant.preferred_email.present? }
    days_until = @event.start_date.present? ? (@event.start_date.to_date - Date.current).to_i : nil

    if registrations.empty?
      redirect_to preview_reminder_event_path(@event), alert: "Please select at least one recipient."
      return
    end

    registrations.each do |event_registration|
      EventMailer.event_registration_reminder(event_registration, days_until_event: days_until).deliver_later
    end

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
        format.html { redirect_to @event, notice: "Event was successfully updated." }
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
    @event.destroy

    respond_to do |format|
      format.html { redirect_to events_path, status: :see_other, notice: "Event was successfully destroyed." }
      format.json { head :no_content }
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

  def event_registrations_csv_string
    require "csv"
    cost_required = @event.cost_cents.to_i > 0
    headers = [ "First name", "Last name", "Email", "Phone", "Organization", "Scholarship recipient", "Scholarship tasks completed", "Payment status", "Payment total" ]
    CSV.generate(headers: headers, write_headers: true) do |csv_out|
      @event_registrations.each do |registration|
        csv_out << event_registration_csv_row(registration, cost_required)
      end
    end
  end

  def event_registration_csv_row(registration, cost_required)
    person = registration.registrant
    orgs = person.affiliations
      .select { |a| !a.inactive? && (a.end_date.nil? || a.end_date >= Date.current) }
      .map(&:organization).compact.uniq
    org_names = orgs.map(&:name).join("; ")
    total_cents = registration.allocations_sum
    payment_total = total_cents.positive? ? format("%.2f", total_cents / 100.0) : ""
    payment_status = cost_required ? (registration.paid_in_full? ? "Paid in full" : "Not paid in full") : ""
    [
      person.first_name,
      person.last_name,
      person.preferred_email.presence || "",
      person.phone_number.presence || "",
      org_names.presence || "",
      registration.scholarships.any? ? "Yes" : "No",
      registration.scholarships.completed.any? ? "Yes" : "No",
      payment_status,
      payment_total
    ]
  end

  def assign_event_forms(event)
    form_id = params.dig(:event, :registration_form_id)
    if form_id.blank?
      event.event_forms.registration.destroy_all
    else
      form = Form.standalone.find_by(id: form_id)
      if form
        existing = event.event_forms.registration.first
        if existing
          existing.update!(form: form) unless existing.form_id == form.id.to_i
        else
          event.event_forms.create!(form: form, role: "registration")
        end
      end
    end

    if params.dig(:event, :scholarship_enabled) == "1"
      form = Form.standalone.find_by(role: "scholarship")
      if form && !event.event_forms.scholarship.exists?
        event.event_forms.create!(form: form, role: "scholarship")
      end
    else
      event.event_forms.scholarship.destroy_all
    end
  end

  def set_form_variables
    @event = @event.decorate
    @event.build_primary_asset if @event.primary_asset.blank?
    @event.gallery_assets.build
    @locations = Location.order(:city, :state)
    @registration_forms = Form.standalone.where(role: [ nil, "", "registration" ]).order(:name)
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
end
