class RegistrationTicketCalloutsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show, :submit_form ]
  before_action :set_event

  # Public detail page for a single registration ticket callout, linked from the
  # call-out on the registration ticket (mirrors the events#details / #ce_hours
  # pages). With no content there is nothing to show, so fall back to the event
  # page — unless the content is merely drip-scheduled, in which case the page
  # shows a "coming soon" note until its display date.
  def show
    @callout = @event.registration_ticket_callouts.find(params[:id])
    authorize! @callout, to: :show?

    # A hidden (draft/opted-out) callout has no public page.
    if @callout.hidden?
      redirect_to event_path(@event, reg: params[:reg].presence)
      return
    end

    if !@callout.page_content? && !@callout.dripping?
      redirect_to event_path(@event, reg: params[:reg].presence)
      return
    end

    @resource_cards = @callout.decorate.resource_cards(registrant_slug: params[:reg].presence, return_to: "callout")

    if @callout.delivers_form? && !@callout.dripping?
      @registration = registrant_from_reg_slug
      @form = @callout.form
      @submission = callout_submission_for(@registration)
      @editing = @submission.nil? || params[:edit].present?
    end

    @event = @event.decorate
  end

  # A registrant submits the form their ticket callout delivers inline. The reg
  # slug is the authorization, mirroring the other public callout pages.
  def submit_form
    @callout = @event.registration_ticket_callouts.find(params[:id])
    @registration = registrant_from_reg_slug

    if @registration.nil? || !@callout.delivers_form? || @callout.hidden? || @callout.dripping?
      redirect_to event_registration_ticket_callout_path(@event, @callout, reg: params[:reg].presence)
      return
    end

    authorize! @registration, to: :show_public?

    EventRegistrationServices::CalloutFormSubmission.call(
      registration: @registration, callout: @callout, form_params: callout_form_params
    )

    redirect_to event_registration_ticket_callout_path(@event, @callout, reg: @registration.slug),
                notice: "Thanks! Your responses have been submitted."
  end

  # Drag-reorder persistence. The shared `sortable` Stimulus controller PUTs the
  # new 1-based position for a single moved callout; the positioning gem reflows
  # the rest. Only event managers can reorder (matches editing the event).
  def update
    @callout = @event.registration_ticket_callouts.find(params[:id])
    authorize! @callout, to: :update?

    if @callout.update(callout_params)
      head :ok
    else
      head :unprocessable_content
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def registrant_from_reg_slug
    slug = params[:reg].presence
    @event.event_registrations.find_by(slug: slug) if slug
  end

  def callout_submission_for(registration)
    return unless registration
    FormSubmission.find_by(person: registration.registrant, form: @callout.form,
                           event: @event, role: EventRegistrationServices::CalloutFormSubmission::ROLE)
  end

  def callout_form_params
    params.dig(:callout_form, :form_fields)&.to_unsafe_h || {}
  end

  def callout_params
    params.permit(:position)
  end
end
