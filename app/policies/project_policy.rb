# frozen_string_literal: true

class ProjectPolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?

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

  # Default scope: admin sees all active, users see their own projects
  scope_for :relation do |relation|
    if admin?
      relation.active
    else
      relation.where(id: user.project_ids)
    end
  end
end
