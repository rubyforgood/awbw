# frozen_string_literal: true

class NotificationPolicy < ApplicationPolicy
  # scope all vs own notifications

  def index?
    authenticated?
  end

  def show?
    authenticated?
  end

  # Scope for notification index - admins see all, others see own
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.where(recipient_email: user.email)
    end
  end
end
