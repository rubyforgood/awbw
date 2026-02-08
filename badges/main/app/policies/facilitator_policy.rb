class FacilitatorPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    authenticated?
  end

  def show?
    admin? || owner? || (authenticated? && record.published? && record.profile_is_searchable?)
  end

  def edit?
    admin? || owner?
  end

  def update?
    admin? || owner?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.searchable # includes `profile_is_searchable`` and `published``
  end

  private

  def owner?
    return false unless authenticated?
    record.user == user
  end
end
