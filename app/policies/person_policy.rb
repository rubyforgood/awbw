class PersonPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    authenticated?
  end

  def show?
    admin? || owner? || (authenticated? && record.profile_is_searchable?)
  end

  def edit?
    admin? || owner?
  end

  def update?
    admin? || owner?
  end

  def destroy?
    admin? && record.persisted? && !has_associated_data?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.searchable.with_active_affiliations
  end

  private

  def owner?
    return false unless authenticated?
    record.user == user
  end

  def has_associated_data?
    record.user.present? ||
      record.affiliations.exists? ||
      record.stories_as_spotlighted_facilitator.exists?
  end
end
