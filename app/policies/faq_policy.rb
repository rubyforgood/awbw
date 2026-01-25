# frozen_string_literal: true

class FaqPolicy < ApplicationPolicy
  # scope active vs all

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

  # Scope for FAQ index - admins see all, others see active
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.active
    end
  end
end
