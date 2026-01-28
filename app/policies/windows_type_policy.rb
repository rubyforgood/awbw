# frozen_string_literal: true

class WindowsTypePolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?

  def create?
    admin?
  end

  def update?
    admin?
  end
end
