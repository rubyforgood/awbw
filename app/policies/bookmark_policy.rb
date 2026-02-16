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
    authenticated?
  end

  def update?
    if record
      admin? || owner?
    else
      authenticated?
    end
  end

  def destroy?
    record.persisted? && (admin? || owner?)
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.where(user: user)
  end
end
