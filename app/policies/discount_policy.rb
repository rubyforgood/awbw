class DiscountPolicy < ApplicationPolicy
  def create?  = admin?
  def destroy? = admin?
end
