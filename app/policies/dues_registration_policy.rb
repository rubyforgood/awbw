class DuesRegistrationPolicy < ApplicationPolicy
  def manage? = admin? && Dues.enabled?
end
