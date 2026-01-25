# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  # index and toggle_lock_status require admin
  # edit self is allowed

  def index?
    admin?
  end

  def show?
    authenticated?
  end

  def create?
    authenticated?
  end

  def update?
    admin? || owner_of_self?
  end

  def destroy?
    admin?
  end

  def toggle_lock_status?
    admin?
  end

  # Scope for projects in user forms
  scope_for :relation, :projects do |relation|
    if admin?
      relation.active
    else
      user.projects
    end
  end

  private

  def owner_of_self?
    record.id == user.id
  end
end
