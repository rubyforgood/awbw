class MembershipInvoicePolicy < ApplicationPolicy
  alias_rule :receipt?, to: :show?

  def manage? = admin? && Membership.enabled?

  def show? = Membership.enabled? && (manage? || owner?)

  def show_public? = Membership.enabled?

  def pay? = Membership.enabled? && owner?

  def edit? = manage? && !record.membership.locked? && !record.payment_in_progress?
  def update? = edit?
  def destroy? = manage? && !record.membership.locked?

  def charge? = manage?

  private

  def owner?
    return false unless authenticated? && record.is_a?(MembershipInvoice)
    record.person == user&.person
  end
end
