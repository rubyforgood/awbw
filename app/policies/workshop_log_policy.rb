class WorkshopLogPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    authenticated?
  end

  def new?
    authenticated?
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

  #
  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    scope = relation.where(user_id: user.id) # owned logs
    if user.organization_ids.present?
      scope = scope.or(relation.organization_ids(user.organization_ids)) # logs from user's projects
    end
    scope
  end
end
