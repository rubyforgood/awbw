class ReportPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  def create?
    authenticated?
  end

  def show?
    admin? || owner? || belongs_to_organization?
  end

  private

  def belongs_to_organization?
    return false unless authenticated?
    record.organization && user.organization_ids.include?(record.organization.id)
  end

  relation_scope do |relation|
    next relation if admin?

    scope = relation.where(user_id: user.id)

    if user.organization_ids.present?
      scope = scope.or(relation.where(project_id: user.organization_ids))
    end

    scope
  end
end
