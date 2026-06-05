class EventRegistrationPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  def index?   = admin?
  def create?  = admin? || owner?
  def update?  = admin? || owner?
  def destroy? = record.persisted? && (admin? || owner?)
  def show? = admin?
  def show_public? = true
  def confirm? = admin?
  def process_confirm? = admin?
  def link_organization? = admin?
  def select_organization? = admin?


  relation_scope do |relation|
    return relation if admin?
    return relation.none unless user
    relation.where(registrant_id: user.person_id)
  end

  private

  def owner?
    return false unless user
    record.registrant_id == user.person_id
  end
end
