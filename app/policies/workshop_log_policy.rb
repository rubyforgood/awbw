# frozen_string_literal: true

class WorkshopLogPolicy < ApplicationPolicy
  # show = admin, owner, or project member
  # index scoped by project membership

  def index?
    authenticated?
  end

  def show?
    admin? || owner? || project_member?
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

  # Scope for workshop log index - admin sees all, others see own or project-related
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.where(created_by_id: user.id)
              .or(relation.project_id(user.project_ids))
    end
  end

  # Scope for workshops in forms
  scope_for :relation, :workshops do |relation|
    if admin?
      relation.all
    else
      relation.published
    end
  end

  # Scope for projects in forms/filters
  scope_for :relation, :projects do |relation|
    if admin?
      relation.active
    else
      user.projects
    end
  end

  private

  def owner?
    record.created_by_id == user.id
  end
end
