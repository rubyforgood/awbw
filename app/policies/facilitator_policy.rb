# frozen_string_literal: true

class FacilitatorPolicy < ApplicationPolicy
  # project scope in forms based on admin status

  def index?
    authenticated?
  end

  def show?
    authenticated?
  end

  def create?
    authenticated?
  end

  def update?
    authenticated?
  end

  def destroy?
    admin?
  end

  # Scope for project selection in forms
  scope_for :relation, :projects do |relation|
    if admin?
      relation.active
    else
      user.projects
    end
  end
end
