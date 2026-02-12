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
    @member ||= begin
      return false unless authenticated?
      return false unless record.organization
      record.organization.organization_people.exists?(person_id: user.person_id)
    end
  end

  relation_scope do |relation|
    next relation if admin?
    relation.where(user_id: user.id)
  end
end
