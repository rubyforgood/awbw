class RegistrationTicketCalloutsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show ]
  before_action :set_event

  # Public detail page for a single registration ticket callout, linked from the
  # call-out on the registration ticket (mirrors the events#details / #ce_hours
  # pages). With no description and no linked resource there is nothing to show,
  # so fall back to the event page.
  def show
    @callout = @event.registration_ticket_callouts.find(params[:id])
    authorize! @callout, to: :show?

    # A hidden (draft/opted-out) or not-yet-dripped callout has no public page.
    if @callout.hidden? || @callout.dripping?
      redirect_to event_path(@event, reg: params[:reg].presence)
      return
    end

    if @callout.description.blank? && @callout.resources.empty?
      redirect_to event_path(@event, reg: params[:reg].presence)
      return
    end

    @resource_cards = build_resource_cards
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

  # This callout's resources as clickable cards linking to each resource's own
  # page (never inline). A registrant reaching the page carries their ticket slug
  # in `reg`, so links go to the in-ticket registrant resource page returning here;
  # without a slug (e.g. an admin preview) they fall back to the resource's own page.
  def build_resource_cards
    reg_slug = params[:reg].presence
    @callout.resources.map do |resource|
      href = if reg_slug
        registration_resource_path(reg_slug, resource, return_to: "callout", callout_id: @callout.id)
      else
        resource_path(resource)
      end
      MagicTicketCallouts::Card.new(icon_class: "fa-solid fa-file-lines", color: "blue",
                                    title: resource.title, subtitle: "Open this document",
                                    href:, target: nil, trailing_icon: "fa-solid fa-arrow-right")
    end
  end

  def set_event
    @event = Event.find(params[:event_id])
  end

  def callout_params
    params.permit(:position)
  end
end
