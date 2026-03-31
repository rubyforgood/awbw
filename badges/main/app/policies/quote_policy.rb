class QuotePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin?
  end

  def show?
    admin? || (authenticated? && record.published?)
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    if authenticated?
      relation.published
    else
      relation.none
    end
  end
end
