# frozen_string_literal: true

class WorkshopMentionPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  # Scope workshops based on admin status
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.published
    end
  end
end
