class OrganizationPersonPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  def destroy?
    admin? # we don't allow users to edit their own
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    if authenticated?
      relation.active
    end
  end
end
