class ProfessionalLicensePolicy < ApplicationPolicy
  # A license is managed (added/edited) by an admin, or by the person who holds it
  # — but only while it has no CE registrations against it. Once any CE
  # registration exists the license locks to admins, since a registrant must not
  # alter the credentials a CE certificate was (or will be) issued under.
  #
  # NOTE: the person edit form is admin-only today (PersonPolicy#edit?/#update?),
  # so this gating is dormant for now. It's in place so that when that policy opens
  # to owners, CE-tied licenses are already protected — no change needed here.
  def edit?
    admin? || (owner? && !record.used_for_ce?)
  end
  alias_rule :new?, :create?, :update?, to: :edit?

  # Deleting a license cascades to its CE registrations, so it's never removable
  # once any CE registration is attached — for admins and owners alike.
  def destroy?
    edit? && record.removable?
  end

  private

  # The holder of the license, via their user account (Person has_one :user).
  def owner?
    return false unless user
    record.person&.user == user
  end
end
