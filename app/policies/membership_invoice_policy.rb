class MembershipInvoicePolicy < ApplicationPolicy
  def manage? = admin? && Membership.enabled?

  def pay? = Membership.enabled? && owner?

  private

  def owner?
    return false unless authenticated? && record.is_a?(MembershipInvoice)
    record.person == user&.person
  end
end
