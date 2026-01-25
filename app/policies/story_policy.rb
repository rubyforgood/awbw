# frozen_string_literal: true

class StoryPolicy < ApplicationPolicy
  # scope published vs all

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

  # Scope for story index - admins see all, others see published
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.published
    end
  end
end
