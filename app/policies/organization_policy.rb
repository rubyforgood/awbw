class OrganizationPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  def index?
    authenticated?
  end

  def show?
    admin? || (authenticated? && record.published?)
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    if admin?
      relation.active
    elsif authenticated?
      # Non-admin users see organizations they belong to
      relation.where(id: user.organization_ids)
    else
      relation.published
    end
  end
end
