class MembershipPolicy < ApplicationPolicy
  def manage? = admin? && Membership.enabled?

  def show?
    return false unless Membership.enabled?
    owner? || manage?
  end

  def checkout? = Membership.enabled? && owner? && !record.autorenewal_cancelled?

  def billing_portal? = Membership.enabled? && owner?

  private

  def owner?
    return false unless authenticated? && record.is_a?(Membership)
    record.person == user&.person
  end
end
