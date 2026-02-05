class FacilitatorPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    authenticated?
  end

  def show?
    admin? || (authenticated? && record.published? && record.profile_is_searchable?)
  end

  def update?
    admin? || owner?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.published.searchable # Do we need 'searchabl'? We have  scope :published, -> { active.searchable }
  end
end
