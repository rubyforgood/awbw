class EventsController < ApplicationController
  include AhoyTracking, TagAssignable
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  skip_before_action :verify_authenticity_token, only: [ :preview ]
  before_action :set_event, only: %i[ show edit update destroy preview manage copy_registration_form ]

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

  def manage
    authorize! @event, to: :manage?
    @event = @event.decorate
    scope = @event.event_registrations
      .includes(:payments, :comments, registrant: [ :user, :contact_methods, { affiliations: :organization }, { avatar_attachment: :blob } ])
      .joins(:registrant)
    scope = scope.keyword(params[:keyword]) if params[:keyword].present?
    scope = scope.attendance_status(params[:attendance_status]) if params[:attendance_status].present?
    @event_registrations = scope.order(Arel.sql("people.first_name, people.last_name"))

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
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
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
      if @event.update(event_params)
        assign_associations(@event)
        assign_event_forms(@event)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
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
    total_cents = registration.successful_payments_total_cents
    payment_total = total_cents.positive? ? format("%.2f", total_cents / 100.0) : ""
    payment_status = cost_required ? (registration.paid_in_full? ? "Paid in full" : "Not paid in full") : ""
    [
      person.first_name,
      person.last_name,
      person.preferred_email.presence || "",
      person.phone_number.presence || "",
      org_names.presence || "",
      registration.scholarship_recipient? ? "Yes" : "No",
      registration.scholarship_tasks_completed? ? "Yes" : "No",
      payment_status,
      payment_total
    ]
  end

  def assign_event_forms(event)
    form_id = params.dig(:event, :registration_form_id)
    return unless form_id

    if form_id.blank?
      event.event_forms.registration.destroy_all
    else
      form = Form.standalone.find_by(id: form_id)
      return unless form

      existing = event.event_forms.registration.first
      if existing
        existing.update!(form: form) unless existing.form_id == form.id.to_i
      else
        event.event_forms.create!(form: form, role: "registration")
      end
    end

    scholarship_form = Form.standalone.find_by(name: ScholarshipApplicationFormBuilder::FORM_NAME)
    if scholarship_form && event.cost_cents.to_i > 0
      event.event_forms.find_or_create_by!(form: scholarship_form, role: "scholarship")
    elsif event.cost_cents.to_i == 0
      event.event_forms.scholarship.destroy_all
    end
  end

  def set_form_variables
    @event = @event.decorate
    @event.build_primary_asset if @event.primary_asset.blank?
    @event.gallery_assets.build
    @locations = Location.order(:city, :state)
    @registration_forms = Form.standalone.where(scholarship_application: false).order(:name)
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
    params.require(:event).permit(:cost,
                                  :created_by_id,
                                  :location_id,
                                  :title,
                                  :pre_title,
                                  :videoconference_url,
                                  :videoconference_label,
                                  :rhino_header,
                                  :rhino_description,
                                  :autoshow_cost,
                                  :autoshow_date,
                                  :autoshow_location,
                                  :autoshow_registration,
                                  :autoshow_time,
                                  :autoshow_title,
                                  :autoshow_videoconference_link,
                                  :autoshow_videoconference_label,
                                  :autoshow_pre_date_text,
                                  :autoshow_registration_close,
                                  :public_registration_enabled,
                                  :pre_title,
                                  :pre_date_text,
                                  :featured,
                                  :start_date, :end_date,
                                  :registration_close_date,
                                  :published,
                                  :publicly_visible,
                                  :publicly_featured,
                                  category_ids: [],
                                  sector_ids: [],
                                  primary_asset_attributes: [ :id, :file, :_destroy ],
                                  gallery_assets_attributes: [ :id, :file, :_destroy ]
                                  )
  end
end
