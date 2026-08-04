class DuesSubscriptionPolicy < ApplicationPolicy
  def manage? = admin?
end
