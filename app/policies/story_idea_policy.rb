class StoryIdeaPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin?
  end

  def show?
    admin? || owner? || credited_author?
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

  def organization_optional?
    admin?
  end

  def destroy?
    record.persisted? && admin?
  end

  private

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end
