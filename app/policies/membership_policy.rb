class MembershipPolicy < ApplicationPolicy
  alias_rule :update?, to: :edit?

  def manage? = admin? && Membership.enabled?

  def show? = manage?

  def edit? = manage? && !record.locked?

  # Who may delete a membership. The Discard service enforces the locked/state
  # guard, so a locked membership can authorize here and still be refused.
  def destroy? = record.persisted? && manage?

  # Removing the next year is a membership operation, not an invoice edit.
  def remove_next_year? = record.persisted? && manage? && !record.locked?

  # Owners choose the card; admins may only turn automatic payments off.
  def enable_autopay? = Membership.enabled? && owner? && !record.locked? && record.renewal_on?
  def disable_autopay? = Membership.enabled? && (manage? || owner?)

  def manage_membership? = Membership.enabled? && owner?

  private

  def owner?
    return false unless authenticated? && record.is_a?(Membership)
    record.person == user&.person
  end
end
