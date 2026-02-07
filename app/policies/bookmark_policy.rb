class BookmarkPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin?
  end

  def personal?
    authenticated?
  end

  def tally?
    admin?
  end

  def create?
    admin? || authenticated? && record.user == user
  end

  def update?
    admin? || owner?
  end

  def destroy?
    admin? || owner?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.where(user: user)
  end
end
