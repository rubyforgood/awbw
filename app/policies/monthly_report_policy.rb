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
    admin? || owner? || member?
  end

  def update?
    admin? || owner? || member?
  end

  def destroy?
    record.persisted? && (admin? || owner? || member?)
  end

  relation_scope do |relation|
    next relation if admin?
    scope = relation.where(user_id: user.id) # owned logs
    if user.person&.organization_ids.present?
      scope = scope.or(relation.organization_ids(user.person&.organization_ids)) # logs from person's affiliations
    end
    scope
  end

  private

  def member?
    @member ||= begin
                  return false unless authenticated?
                  return false unless record.organization
                  record.organization.affiliations.exists?(person_id: user.person_id)
                end
  end
end
