class MonthlyReportPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  def show?
    admin? || owner? || member?
  end

  def update?
    admin? || owner? || member?
  end

  def destroy?
    admin? || owner? || member?
  end

  private

  def member?
    return false unless authenticated?
    return false unless record.organization
    user.organization_ids.include?(record.organization.id)
  end

  relation_scope do |relation|
    next relation if admin?
    relation.where(user_id: user.id)
  end
end
