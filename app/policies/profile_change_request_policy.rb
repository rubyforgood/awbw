class ProfileChangeRequestPolicy < ApplicationPolicy
  # `edit` and `update` share the same rule, so `authorize! @request` in either
  # action infers the right check without passing `to:`.
  alias_rule :edit?, to: :update?

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

  def update?
    (admin? || owner?) && record.pending?
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
