class ProfileChangeRequestPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin? || owner?
  end

  def new?
    admin? || owner?
  end

  def create?
    admin? || owner?
  end

  def approve?
    admin?
  end

  def decline?
    admin?
  end

  def resolve?
    admin?
  end

  relation_scope do |relation|
    next relation if admin?
    next relation.none unless authenticated?
    relation.where(person: user.person)
  end

  private

  def owner?
    return false unless authenticated?
    record.person&.user == user
  end
end
