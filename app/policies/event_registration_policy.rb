class EventRegistrationPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  def index?   = admin?
  def show?    = admin? || owner?
  def create?  = admin? || owner?
  def update?  = admin? || owner?
  def destroy? = admin? || owner?


  relation_scope do |relation|
    return relation if admin?
    return relation.none unless user

    # regular users only see their own
    relation.where(registrant_id: user.id)
  end

  private

  def owner?
    return false unless user
    record.registrant_id == user.id
  end
end
