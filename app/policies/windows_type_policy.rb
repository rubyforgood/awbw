# frozen_string_literal: true

class WindowsTypePolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?

  def index?
    authenticated?
  end

  def show?
    authenticated?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end
end
