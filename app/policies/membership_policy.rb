class MembershipPolicy < ApplicationPolicy
  alias_rule :update?, to: :edit?
  alias_rule :show?, to: :manage?
  alias_rule :unlock, to: destory?

  def manage? = admin? && Membership.enabled?

  def edit? = manage? && !record.locked?

  def destroy? = record.persisted? && manage?

  def remove_next_year? = record.persisted? && manage? && !record.locked?

  def enable_autopay? = Membership.enabled? && owner? && !record.locked? && record.renewal_on?
  def disable_autopay? = Membership.enabled? && (manage? || owner?)

  def manage_membership? = Membership.enabled? && owner?

  private

  def owner?
    return false unless authenticated? && record.is_a?(Membership)
    record.person == user&.person
  end
end
