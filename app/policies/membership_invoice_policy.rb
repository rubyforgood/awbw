class MembershipInvoicePolicy < ApplicationPolicy
  alias_rule :receipt?, to: :show?
  alias_rule :create?, to: :new?
  alias_rule :update?, to: :edit?

  def manage? = admin? && Membership.enabled?

  def show? = Membership.enabled? && (manage? || owner?)

  def show_public? = Membership.enabled?

  def pay? = Membership.enabled? && owner?

  def new? = manage? && !record.membership.locked?

  def edit? = manage? && !record.membership.locked? && !record.payment_in_progress? && !record.unresolved_attempt?
  def destroy? = record.persisted? && manage? && !record.membership.locked?
  def reconcile? = manage?

  private

  def owner?
    return false unless authenticated? && record.is_a?(MembershipInvoice)
    record.person == user&.person
  end
end
