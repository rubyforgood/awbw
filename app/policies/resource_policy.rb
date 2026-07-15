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

  def search?
    authenticated?
  end

  def update?
    admin?
  end

  def download?
    show?
  end

  def filter_published?
    admin?
  end

  relation_scope do |relation|
    next relation if admin?
    visible = authenticated? ? relation.published : relation.publicly_visible
    visible.searchable
  end
end
