# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  # edit = admin or creator
  # destroy = admin only
  # scope published vs all
  alias_rule :edit?, to: :update?

  def update?
    admin? || creator?
  end

  # Scope for event index - admins see all, others see published
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.published
    end
  end

  private

  def creator?
    record.created_by_id == user.id
  end
end
