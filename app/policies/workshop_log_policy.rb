class WorkshopLogPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    authenticated?
  end

  def new?
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
  #
  relation_scope do |relation|
    next relation if admin?
    relation.where(user_id: user.id)
            .or(WorkshopLog.project_id(user.project_ids)) # allow users to see peers' within same organization
  end
end
