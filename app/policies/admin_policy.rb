# frozen_string_literal: true

class AdminPolicy < ApplicationPolicy
  # Policy for admin namespace access
  # Used for Admin::BaseController authorization

  def admin?
    user&.super_user?
  end

  # All admin actions require admin status
  def index?
    admin?
  end

  def show?
    admin?
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
