# Public, per-person verification page for a facilitator-training credential,
# reached from the certUrl on a registrant's LinkedIn "Add to Profile" badge. It
# validates one registrant's single credential (by their unguessable slug) — never
# a roster. The slug is the authorization, so no login is required (mirrors the
# public ticket/callout pages).
class CredentialsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @event_registration = EventRegistration.find_by!(slug: params[:slug])
    authorize! @event_registration, to: :show_public?

    # A credential exists only for an attended facilitator training whose
    # certificate has unlocked — anything else isn't verifiable through this page.
    unless @event_registration.event.facilitator_training? && @event_registration.certificate_available?
      raise ActiveRecord::RecordNotFound
    end

    @event = @event_registration.event.decorate
  end
end
