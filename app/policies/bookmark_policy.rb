class BookmarkPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # def index?
  #   true
  # end

  def personal?
    authenticated?
  end

  def tally?
    admin?
  end

  def create?
    # TODO check bookmark owner
    true
  end

  def update?
    # TODO check bookmark owner
    true
  end

  def destroy?
    # TODO check bookmark owner
    true
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.where(user: user)
  end
end
