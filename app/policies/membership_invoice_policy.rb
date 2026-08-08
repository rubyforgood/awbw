class MembershipInvoicePolicy < ApplicationPolicy
  def manage? = admin? && Membership.enabled?
end
