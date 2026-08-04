class ContinuingEducationRegistrationsController < ApplicationController
  before_action :set_ce_registration, except: [ :index, :new, :create ]
  before_action :set_event_registration, only: [ :new, :create ]

  def index
    authorize!
    base = ContinuingEducationRegistration.search_by_params(params)
    # Totals over the whole (unpaginated) filtered set so the header stays true
    # across pages.
    @ce_total_cost_cents = base.sum(:cost_cents)
    @ce_total_hours = base.sum(:hours)
    @ce_registrations = base.includes(:allocations, professional_license: [], event_registration: [ :registrant, :event ])
      .order(created_at: :desc)
      .paginate(page: params[:page], per_page: 25)
    render :continuing_education_registrations_results if turbo_frame_request?
  end

  def show
    authorize! @ce_registration
  end

  def new
    authorize!
    @ce_registration = @event_registration.continuing_education_registrations.build(
      professional_license: @event_registration.registrant.professional_licenses.first,
      hours: @event_registration.event.ce_hours_offered,
      cost_cents: @event_registration.event.ce_hours_cost_cents
    )
  end

  def create
    authorize!

    @ce_registration = @event_registration.continuing_education_registrations.build(professional_license: license_for_create)

    # License and CE registration persist together — a failed save leaves neither.
    ActiveRecord::Base.transaction do
      apply_ce_params(@ce_registration)
      @ce_registration.save!
    end
    redirect_to helpers.ce_registration_return_path(@ce_registration.event_registration), notice: "CE registration created.", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = error_sentence(e.record)
    render :new, status: :unprocessable_content
  end

  def edit
    authorize! @ce_registration
  end

  def update
    authorize! @ce_registration

    ActiveRecord::Base.transaction do
      apply_ce_params(@ce_registration)
      @ce_registration.save!
      apply_time_entries(@ce_registration.event_registration)
    end
    redirect_to helpers.ce_registration_return_path(@ce_registration.event_registration), notice: "CE registration updated.", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = error_sentence(e.record)
    render :edit, status: :unprocessable_content
  end

  def destroy
    authorize! @ce_registration
    if @ce_registration.allocations.exists?
      redirect_to edit_continuing_education_registration_path(@ce_registration, return_to: params[:return_to]),
        alert: "Can't remove CE — it has payments. Revert the payment first.", status: :see_other
      return
    end

    registration = @ce_registration.event_registration
    @ce_registration.destroy!
    redirect_to helpers.ce_registration_return_path(registration), notice: "CE registration removed.", status: :see_other
  end

  def toggle_certificate
    authorize! @ce_registration
    issued = @ce_registration.certificate_sent_at.present?
    @ce_registration.update!(certificate_sent_at: issued ? nil : Time.current)
    redirect_to edit_continuing_education_registration_path(@ce_registration, return_to: params[:return_to]),
      notice: issued ? "Certificate marked not issued." : "Certificate marked issued.", status: :see_other
  end

  private

  # A failed save's errors as one sentence. Attendance-entry failures arrive on the
  # parent registration keyed "event_attendance_time_entries.base", whose full message
  # pastes the humanized association name onto a message already written as a whole
  # sentence — show those verbatim, and keep full messages for the CE record's own
  # attributes ("Hours can't be blank").
  def error_sentence(record)
    record.errors.map { |error|
      error.attribute.to_s.include?(".") ? error.message : error.full_message
    }.to_sentence
  end

  def set_ce_registration
    @ce_registration = ContinuingEducationRegistration.find(params[:id])
  end

  def set_event_registration
    sgid = params[:allocatable_sgid]
    @event_registration = GlobalID::Locator.locate_signed(sgid) if sgid
    redirect_to root_path, alert: "Registration not found.", status: :see_other unless @event_registration
  end

  def license_for_create
    @event_registration.registrant.professional_licenses.first ||
      @event_registration.registrant.professional_licenses.build
  end

  def apply_ce_params(ce_registration)
    ce_registration.assign_license(number: params.dig(:continuing_education_registration, :license_number),
                                   kind: params.dig(:continuing_education_registration, :license_kind),
                                   issuing_state: params.dig(:continuing_education_registration, :license_issuing_state),
                                   expires_on: params.dig(:continuing_education_registration, :license_expires_on),
                                   license_id: params.dig(:continuing_education_registration, :professional_license_id))
    ce_registration.hours = params.dig(:continuing_education_registration, :hours)
    cost = params.dig(:continuing_education_registration, :cost_dollars)
    ce_registration.cost_cents = (cost.to_d * 100).round if cost.present?

    comments = params.fetch(:continuing_education_registration, {})
      .permit(comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ])[:comments_attributes]
    ce_registration.comments_attributes = comments if comments.present?
  end

  # Staff corrections to the registrant's attendance times, submitted alongside the
  # CE form under continuing_education_registration[time_entries]. Mapped onto the
  # registration's nested-attributes setter (create/update/destroy), then attributed
  # to current_user — these are the only attributed entries (self-service is not).
  def apply_time_entries(registration)
    rows = time_entries_attributes
    return if rows.blank?

    # Drop rows pointing at an entry that's no longer on this registration — a stale
    # form or double-submit (it was already removed). Left in, nested attributes raise
    # RecordNotFound and blow up the save.
    existing_ids = registration.event_attendance_time_entries.pluck(:id).map(&:to_s)
    rows = rows.reject { |row| row["id"].present? && existing_ids.exclude?(row["id"].to_s) }
    return if rows.blank?

    registration.assign_attributes(event_attendance_time_entries_attributes: rows)
    registration.event_attendance_time_entries.each do |entry|
      next if entry.marked_for_destruction?

      entry.created_by ||= current_user if entry.new_record?
      entry.updated_by = current_user if entry.new_record? || entry.changed?
    end
    registration.save!
  end

  def time_entries_attributes
    params.fetch(:continuing_education_registration, {})
          .permit(time_entries: [ :id, :signed_in_at, :signed_out_at, :_destroy ])
          .fetch(:time_entries, {})
          .values
  end
end
