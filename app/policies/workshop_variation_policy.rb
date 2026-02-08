class WorkshopVariationPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin? || owner?
  end

  def create?
    admin? || owner?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  relation_scope do |relation|
    next relation if admin?
    relation.where(created_by: user)
  end
end
