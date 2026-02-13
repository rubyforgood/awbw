class WorkshopIdeaPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin?
  end

  def new?
    # authenticated?
    admin? # Temp block until stakeholders are ready
  end

  def create?
    authenticated?
  end

  def update?
    admin?# || owner?
  end

  def show?
    admin? || owner?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end
