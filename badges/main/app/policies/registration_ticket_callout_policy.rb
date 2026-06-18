class RegistrationTicketCalloutPolicy < ApplicationPolicy
  # The callout detail page is public reading reached from the registration
  # ticket. It must be viewable by anyone with the link — including registrants
  # of ended or non-public events — so it does not mirror Event#show?. The
  # callout id is scoped to its event, so there is nothing sensitive to gate.
  def show?
    true
  end

  # Drag-reorder persistence is editing the event, so it stays manager-only.
  def update?
    allowed_to?(:manage?, record.event)
  end
end
