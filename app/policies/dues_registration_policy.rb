class DuesRegistrationPolicy < ApplicationPolicy
  def manage? = admin?
end
