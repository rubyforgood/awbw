class StoryIdeaPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin?
  end

  def show?
    admin? || owner?
  end

  def new?
    authenticated?
  end

  def create?
    authenticated?
  end

  def update?
    admin?# || owner?
  end

  def destroy?
    admin?
  end

  private

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping
  #
  # relation_scope do |relation|
  #   next relation if admin?
  #   relation.where(user: user)
  # end
end
