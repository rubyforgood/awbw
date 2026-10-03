class StorySharePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  def index?
    true
  end

  def show?
    return false if record.funder_only?
    admin? || record.publicly_visible? || (authenticated? && record.published?)
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping
  #
  # Funder-only stories never belong on the Story Share showcase — excluded for
  # every audience, admins included.
  relation_scope do |relation|
    scope = relation.not_funder_only
    next scope if admin?
    if authenticated?
      scope.published
    else
      scope.publicly_visible
    end
  end
end
