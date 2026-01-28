# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  # index and toggle_lock_status require admin
  # edit self is allowed

  def index?
    admin?
  end

  def update?
    admin? || owner_of_self?
  end

  def toggle_lock_status?
    admin?
  end

  private

  def owner_of_self?
    record.id == user.id
  end
end
