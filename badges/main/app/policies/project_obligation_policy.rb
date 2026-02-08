class ProjectObligationPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?


  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping
  #
  # relation_scope do |relation|
  #   next relation if admin?
  #   relation.where(user: user)
  # end
end
