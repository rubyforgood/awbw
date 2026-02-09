class ResourcePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  def index?
    true
  end

  def show?
    admin? || record.publicly_visible? || (authenticated? && record.published?)
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def download?
    true
  end

  def filter_published?
    admin?
  end

  relation_scope do |relation|
    next relation if admin?
    if authenticated?
      relation.published
    else
      relation.publicly_visible
    end
  end
end
