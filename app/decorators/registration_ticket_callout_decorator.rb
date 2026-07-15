class RegistrationTicketCalloutDecorator < ApplicationDecorator
  # This callout's linked resources as cards, in display order, each reading its
  # subtitle from the materialized join row and linking to the resource's own
  # page. Shared by every surface that lists a callout's resources (the handouts
  # and built-in callout pages, and the generic callout page) so they can't drift.
  # `return_to` identifies this origin for the resource page's eyebrow; the
  # callout id is passed only for the generic callout page (return_to "callout").
  def resource_cards(registrant_slug:, return_to:, icon: "fa-solid fa-file-lines")
    registration_ticket_callout_resources.ordered.includes(:resource).filter_map do |link|
      next unless link.resource
      link.decorate.to_card(registrant_slug:, return_to:, icon:,
                            callout_id: (id if return_to == "callout"))
    end
  end
end
