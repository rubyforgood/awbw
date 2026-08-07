class MembershipCheckoutPolicy < ApplicationPolicy
  def create? = Membership.enabled? && user&.person.present?
end
