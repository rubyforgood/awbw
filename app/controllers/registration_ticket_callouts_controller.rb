class RegistrationTicketCalloutsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show ]
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
    @event = @event.decorate
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
      head :unprocessable_entity
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def callout_params
    params.permit(:position)
  end
end
