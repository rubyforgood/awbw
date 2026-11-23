class MonthlyReportPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  def new?
    authenticated?
  end

  def create?
    authenticated?
  end

  def show?
    admin? || owner? || affiliated_with?
  end

  def update?
    admin? || owner? || affiliated_with?
  end

  def destroy?
    record.persisted? && (admin? || owner? || affiliated_with?)
  end

  relation_scope do |relation|
    next relation if admin?
    scope = relation.where(created_by_id: user.id) # owned logs
    if user.person&.organization_ids.present?
      scope = scope.or(relation.organization_ids(user.person&.organization_ids)) # logs from person's affiliations
    end
    scope
  end

  private

  def affiliated_with?
    return false unless authenticated?
    return false unless record.organization
    record.organization.affiliations.exists?(person_id: user.person_id)
  end
end
