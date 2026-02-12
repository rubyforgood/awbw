class OrganizationPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  def index?
    authenticated?
  end

  def show?
    admin? || (authenticated? && record.published?)
  end

  def show_logs?
    admin? || member?
  end

  private

  def member?
    return false unless user&.person_id
    record.organization_people.pluck(:person_id).include?(user.person_id)
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.published
  end
end
