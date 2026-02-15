class WorkshopVariationIdeaPolicy < ApplicationPolicy
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

  def edit?
    admin?
  end

  def update?
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
    authenticated? ? relation.where(created_by_id: created_by_id) : relation.none
  end
end
