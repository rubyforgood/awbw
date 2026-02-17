class WorkshopVariationPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    admin? || (authenticated? && record.published?)
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    record.persisted? && admin?
  end

  relation_scope do |relation|
    next relation if admin?
    if authenticated?
      relation.published.or(relation.where(created_by_id: user.id))
    else
      relation.publicly_visible
    end
  end
end
