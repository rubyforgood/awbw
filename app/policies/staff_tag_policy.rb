class StaffTagPolicy < ApplicationPolicy
  # Staff tags are internal, admin-only. Every action is gated to admins, and the
  # relation scope hides them entirely from everyone else.
  def index?     = admin?
  def show?      = admin?
  def create?    = admin?
  def update?    = admin?
  def destroy?   = record.persisted? && admin?
  def archive?   = admin?
  def unarchive? = admin?

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end
