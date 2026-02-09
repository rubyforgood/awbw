class CategoryPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?

  def tags_index?
    true
  end

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end
