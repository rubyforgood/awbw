# frozen_string_literal: true

class MonthlyReportPolicy < ApplicationPolicy
  # show = admin or project member

  def index?
    authenticated?
  end

  def show?
    admin? || project_member?
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
