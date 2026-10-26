class MembershipPolicy < ApplicationPolicy
  def manage? = admin? && Membership.enabled?

  def show?
    return false unless Membership.enabled?
    owner? || manage?
  end

  def manage_subscription?
    Membership.enabled? && owner?
  end

  def set_up_subscription?
    manage_subscription? && !record.autorenewal_cancelled?
  end

  private

  def owner?
    return false unless authenticated? && record.is_a?(Membership)
    record.person == user&.person
  end
end
