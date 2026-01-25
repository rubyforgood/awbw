# frozen_string_literal: true

class WorkshopVariationPolicy < ApplicationPolicy
  # index = admin only

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
end
