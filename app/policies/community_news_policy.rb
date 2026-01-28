# frozen_string_literal: true

class CommunityNewsPolicy < ApplicationPolicy
  # scope published vs all
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

  # Scope for community news index - admins see all, others see published
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.published
    end
  end
end
