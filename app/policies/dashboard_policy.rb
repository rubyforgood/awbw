# frozen_string_literal: true

class DashboardPolicy < ApplicationPolicy
  # admin dashboard = admin only

  # For accessing the admin dashboard
  def admin_dashboard?
    admin?
  end

  # For viewing other users' recent activities
  def view_other_user_activities?
    admin?
  end
end
