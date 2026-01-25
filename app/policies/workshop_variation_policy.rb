# frozen_string_literal: true

class WorkshopVariationPolicy < ApplicationPolicy
  # index = admin only
  # create scope based on admin status

  def index?
    admin?
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
      relation.published
    end
  end
end
