# frozen_string_literal: true

class EventRegistrationPolicy < ApplicationPolicy
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
end
