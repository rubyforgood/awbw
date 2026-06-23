class OrganizationTypePolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = record.persisted? && admin?

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end
