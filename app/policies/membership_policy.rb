class MembershipPolicy < ApplicationPolicy
  def manage? = admin? && Membership.enabled?

  def show?
    return false unless Membership.enabled?
    return true if manage?
    return false unless record.is_a?(Membership)

    owner? && !record.locked?
  end

  def edit? = manage? && !record.locked?
  def update? = edit?
  def destroy? = edit?

  def issue_next_invoice? = edit?
  def remove_next_year? = edit?
  def cancel_renewal? = edit?
  def resume_renewal? = edit?

  def manage_subscription? = Membership.enabled? && owner?

  private

  def owner?
    return false unless authenticated? && record.is_a?(Membership)
    record.person == user&.person
  end
end
