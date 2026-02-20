class WorkshopPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    true
  end

  def show?
    admin? || record.publicly_visible? || (authenticated? && record.published?)
  end

  def destroy?
    record.persisted? && admin?
  end

  def search?
    authenticated?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping
  #
  relation_scope do |relation|
    next relation if admin?
    authenticated? ? relation.published : relation.publicly_visible
  end
end
