class ContinuingEducationRegistrationsController < ApplicationController
  before_action :set_ce_registration, except: [ :new, :create ]
  before_action :set_event_registration, only: [ :new, :create ]

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
    redirect_to helpers.ce_registration_return_path(@ce_registration.event_registration, params[:return_to]), notice: "CE registration created.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = @ce_registration.errors.full_messages.to_sentence
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
    end
    redirect_to helpers.ce_registration_return_path(@ce_registration.event_registration, params[:return_to]), notice: "CE registration updated.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = @ce_registration.errors.full_messages.to_sentence
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
    redirect_to helpers.ce_registration_return_path(registration, params[:return_to]), notice: "CE registration removed.", status: :see_other
  end

  def toggle_certificate
    authorize! @ce_registration
    issued = @ce_registration.certificate_sent_at.present?
    @ce_registration.update!(certificate_sent_at: issued ? nil : Time.current)
    redirect_to edit_continuing_education_registration_path(@ce_registration, return_to: params[:return_to]),
      notice: issued ? "Certificate marked not issued." : "Certificate marked issued.", status: :see_other
  end

  private

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
end
