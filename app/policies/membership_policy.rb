class MembershipPolicy < ApplicationPolicy
  alias_rule :update?, :destroy?, to: :edit?
  alias_rule :unlock?, to: :manage?

  def manage? = admin? && Membership.enabled?

  def show? = manage?

  def edit? = manage? && !record.locked?

  def enable_autopay? = Membership.enabled? && owner? && !record.locked?
  def disable_autopay? = manage? || owner?

  def manage_subscription? = Membership.enabled? && owner?

  private

  def owner?
    return false unless authenticated? && record.is_a?(Membership)
    record.person == user&.person
  end
end
