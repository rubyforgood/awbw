class MembershipInvoicePolicy < ApplicationPolicy
  alias_rule :receipt?, to: :show?

  def manage? = admin? && Membership.enabled?

  def show? = Membership.enabled? && (manage? || owner?)

  def pay? = Membership.enabled? && owner?

  private

  def owner?
    return false unless authenticated? && record.is_a?(MembershipInvoice)
    record.person == user&.person
  end
end
