# frozen_string_literal: true

class MonthlyReportPolicy < ApplicationPolicy
  # show = admin or project member

  def show?
    admin? || project_member?
  end
end
