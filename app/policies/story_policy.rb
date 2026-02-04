class StoryPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  def index?
    true
  end

  def show?
    admin? || record.published? || (authenticated? && record.public?)
  end
  #
  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping
  #
  relation_scope do |relation|
    next relation if admin?
    if authenticated?
      relation.published
    else
      relation.public
    end
  end
end
