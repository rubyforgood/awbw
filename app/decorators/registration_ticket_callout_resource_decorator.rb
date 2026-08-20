class RegistrationTicketCalloutResourceDecorator < ApplicationDecorator
  # The short line shown on this resource's callout card: the admin-editable
  # subtitle materialized on the join row, or a neutral fallback when blank.
  def card_subtitle
    subtitle.presence || "Open this document"
  end

  # This linked resource rendered as a callout card. A registrant (with a ticket
  # slug) stays in-tab on the resource's own page and returns to this origin;
  # without a slug (the sample ticket / admin preview) it falls back to the
  # resource's plain admin page. `return_to` names the origin so the resource
  # page's eyebrow returns here; `callout_id` is only needed for the generic
  # callout page and is dropped from the URL when nil. `color` themes the card —
  # blue on the callout pages, grey in the payment page's documents list.
  def to_card(registrant_slug:, return_to:, icon: "fa-solid fa-file-lines", color: "blue", callout_id: nil)
    BuiltinCalloutCards::Card.new(
      icon_class: icon, color:, title: resource.title, subtitle: card_subtitle,
      href: card_href(registrant_slug:, return_to:, callout_id:),
      target: nil, trailing_icon: "fa-solid fa-arrow-right"
    )
  end

  private

  def card_href(registrant_slug:, return_to:, callout_id:)
    return h.resource_path(resource) unless registrant_slug
    h.registration_resource_path(registrant_slug, resource, return_to:, callout_id:)
  end
end
