class ScholarshipPolicy < ApplicationPolicy
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
