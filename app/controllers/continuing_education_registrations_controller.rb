class ContinuingEducationRegistrationsController < ApplicationController
  before_action :set_ce_registration

  def edit
    authorize! @ce_registration
  end

  def update
    authorize! @ce_registration
    assign_license(params.dig(:continuing_education_registration, :license_number))
    @ce_registration.hours = params.dig(:continuing_education_registration, :hours)
    cost = params.dig(:continuing_education_registration, :cost_dollars)
    @ce_registration.cost_cents = (cost.to_d * 100).round if cost.present?

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

  # Set/replace the license from a typed number. Promote a placeholder in place
  # (no orphaned placeholder) when the number is new to the person; otherwise
  # repoint to the person's existing/created license for that number.
  def assign_license(number)
    number = number.to_s.strip.presence
    return if number.nil?

    person = @ce_registration.event_registration.registrant
    current = @ce_registration.professional_license
    existing = person.professional_licenses.find_by(number: number)

    if current && !current.number_known? && existing.nil?
      current.update!(number: number)
    else
      @ce_registration.professional_license = existing || ProfessionalLicense.find_or_create_for(person: person, number: number)
    end
  end

  def registration_path
    edit_event_registration_path(@ce_registration.event_registration)
  end
end
