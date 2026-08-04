class PersonPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin?
  end

  def show?
    admin? || owner?
  end

  def workshop_logs?
    admin? || owner?
  end

  def show_email_change?
    admin? || owner?
  end

  def checkout?
    admin?
  end

  def edit?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin? && record.persisted? && record.deletable?
  end

  def search?
    admin?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.searchable.with_active_affiliations.where_user_not_locked
  end

  private

  def owner?
    return false unless authenticated?
    record.user == user
  end
end
