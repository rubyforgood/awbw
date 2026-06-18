class RegistrationTicketCalloutsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show ]
  before_action :set_event

  # Public detail page for a single registration ticket callout, linked from the
  # call-out on the registration ticket (mirrors the events#details / #ce_hours
  # pages). When the callout has no description there is nothing to read, so fall
  # back to the event page.
  def show
    @callout = @event.registration_ticket_callouts.find(params[:id])
    authorize! @callout, to: :show?

    if @callout.description.blank?
      redirect_to event_path(@event, reg: params[:reg].presence)
      return
    end

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
