# Where one registrant lands for one ticket callout — or for one resource linked
# on it — mirroring the card on their ticket. Backs the bulk-email "open this
# callout" button: the email links to a per-registrant redirect
# (Events::CalloutsController#go) that asks this object for the destination at
# click time, so drip dates and gates are read when the person clicks, not when
# the email went out.
#
# #path is nil when the ticket wouldn't show this card to the registrant (unpublished,
# gated, transferred out) or the card has no page to open; callers fall back to
# the ticket itself.
class RegistrantCalloutLink
  include Rails.application.routes.url_helpers

  # The page a non-behavioral (custom or content built-in) callout card opens on
  # a real ticket: its person-first forms page when it delivers forms, else the
  # event-scoped callout page carrying the registrant's slug. Shared with the
  # ticket so the card and the email button can't drift.
  def self.custom_callout_path(registration, callout)
    helpers = Rails.application.routes.url_helpers
    if callout.delivers_form?
      helpers.registration_callout_form_path(registration.slug, callout)
    else
      helpers.event_registration_ticket_callout_path(registration.event, callout, reg: registration.slug)
    end
  end

  attr_reader :registration, :callout, :resource

  def initialize(registration, callout, resource: nil)
    @registration = registration
    @callout = callout
    @resource = resource
  end

  # The button text's subject: the resource's title, else the callout's.
  def label
    resource&.title.presence || callout.title
  end

  def path
    return unless registration.slug.present? && callout.event_id == registration.event_id
    return unless callout.shown_to?(registration)

    resource ? resource_path : callout_path
  end

  private

  def callout_path
    return builtin_card&.href if callout.behavioral_builtin?
    return unless callout.page_content?

    self.class.custom_callout_path(registration, callout)
  end

  # A resource is only reachable through a callout that links it — and, for a
  # behavioral built-in, only once its live card applies to this registrant.
  def resource_path
    return unless callout.registration_ticket_callout_resources.exists?(resource_id: resource.id)
    return if callout.behavioral_builtin? && builtin_card.nil?

    return_to = resource_return_to
    registration_resource_path(registration.slug, resource, return_to:,
                               callout_id: (callout.id if return_to.in?(%w[ callout callout_form ])))
  end

  # The origin the resource page's eyebrow returns to — the page that lists this
  # callout's resources (see RegistrationTicketCalloutDecorator#resource_cards).
  def resource_return_to
    return callout.builtin_key if callout.behavioral_builtin?

    callout.delivers_form? ? "callout_form" : "callout"
  end

  def builtin_card
    return @builtin_card if defined?(@builtin_card)

    @builtin_card = BuiltinCalloutCards.new(registration).card_for(callout)
  end
end
