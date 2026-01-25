# frozen_string_literal: true

class QuotePolicy < ApplicationPolicy
  # workshop scope in forms based on admin status

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

  # Scope for workshop selection in forms
  scope_for :relation, :workshops do |relation|
    if admin?
      relation.all
    else
      relation.active
    end
  end
end
