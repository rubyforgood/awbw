class ContinuingEducationRegistrationsController < ApplicationController
  before_action :set_ce_registration, except: [ :new, :create ]
  before_action :set_event_registration, only: [ :new, :create ]

  # Deliberate "Add CE registration" path, mirroring scholarship's new/create.
  # The "Requested" toggle on the registration form still auto-creates a stub on
  # save; this is the alternative where the admin fills in license/hours/cost up
  # front. Hours/cost prefill from the event's offering.
  def new
    @ce_registration = @event_registration.continuing_education_registrations.build(
      professional_license: @event_registration.registrant.professional_licenses.first,
      hours: @event_registration.event.ce_hours_offered,
      cost_cents: @event_registration.event.ce_hours_cost_cents
    )
    authorize! @ce_registration
  end

  def create
    @ce_registration = @event_registration.continuing_education_registrations.build(professional_license: license_for_create)
    authorize! @ce_registration
    apply_ce_params(@ce_registration)

    if @ce_registration.save
      @event_registration.update_column(:ce_requested, true)
      redirect_to registration_path, notice: "CE registration created.", status: :see_other
    else
      flash.now[:alert] = @ce_registration.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @ce_registration
  end

  def update
    authorize! @ce_registration
    apply_ce_params(@ce_registration)

    if @ce_registration.save
      redirect_to registration_path, notice: "CE registration updated.", status: :see_other
    else
      flash.now[:alert] = @ce_registration.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  # Removal mirrors scholarship's destroy but never cascades away a CE registration
  # that carries payments — the admin must revert the allocation first.
  def destroy
    authorize! @ce_registration
    if @ce_registration.allocations.exists?
      redirect_to edit_continuing_education_registration_path(@ce_registration, return_to: params[:return_to]),
        alert: "Can't remove CE — it has payments. Revert the payment first.", status: :see_other
      return
    end

    registration = @ce_registration.event_registration
    @ce_registration.destroy!
    registration.update_column(:ce_requested, false)
    redirect_to edit_event_registration_path(registration), notice: "CE registration removed.", status: :see_other
  end

  # Mark / unmark the CE certificate as issued (sets/clears certificate_sent_at),
  # mirroring scholarship's toggle_tasks.
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

  # The registration a new CE record attaches to, located from the signed global
  # id the "Add CE registration" link carries (mirrors scholarship's allocatable).
  def set_event_registration
    sgid = params[:allocatable_sgid] || params.dig(:continuing_education_registration, :allocatable_sgid)
    @event_registration = GlobalID::Locator.locate_signed(sgid) if sgid
    redirect_to root_path, alert: "Registration not found.", status: :see_other unless @event_registration
  end

  # License a brand-new CE registration attaches to: the registrant's existing
  # license, else an empty placeholder. assign_license then fills it from the
  # submitted type/number/state/expiry. Mirrors EventRegistrationsController.
  def license_for_create
    @event_registration.registrant.professional_licenses.first ||
      ProfessionalLicense.find_or_create_for(person: @event_registration.registrant)
  end

  # Apply the submitted license fields, hours, and cost to a CE registration.
  # Shared by create and update so both read params the same way.
  def apply_ce_params(ce_registration)
    ce_registration.assign_license(number: params.dig(:continuing_education_registration, :license_number),
                                   kind: params.dig(:continuing_education_registration, :license_kind),
                                   issuing_state: params.dig(:continuing_education_registration, :license_issuing_state),
                                   expires_on: params.dig(:continuing_education_registration, :license_expires_on),
                                   license_id: params.dig(:continuing_education_registration, :professional_license_id))
    ce_registration.hours = params.dig(:continuing_education_registration, :hours)
    cost = params.dig(:continuing_education_registration, :cost_dollars)
    ce_registration.cost_cents = (cost.to_d * 100).round if cost.present?
  end

  def registration_path
    edit_event_registration_path(@ce_registration.event_registration)
  end
end
