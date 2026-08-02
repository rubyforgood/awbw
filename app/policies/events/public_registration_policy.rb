class Events::PublicRegistrationPolicy < ApplicationPolicy
  # Anonymous visitors may only reach the public registration/scholarship form
  # when public registration is enabled for the event. Signed-in users (and
  # admins, who are always signed in) may always reach it — mirroring the
  # register button, which shows for any signed-in user on a registerable event.
  # `record` is the event (authorized via `authorize! @event, with: self`).
  def new?
    admin? || record.public_registration_enabled? || authenticated?
  end

  def create?
    new?
  end

  def show?
    true
  end
end
