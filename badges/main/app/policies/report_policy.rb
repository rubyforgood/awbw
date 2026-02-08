class ReportPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  def create?
    authenticated?
  end

  def show?
    admin? || owner?
  end

  relation_scope do |relation|
    next relation if admin?

    scope = relation.where(user_id: user.id)

    if user.project_ids.present?
      scope = scope.or(relation.where(project_id: user.project_ids))
    end

    scope
  end
end
