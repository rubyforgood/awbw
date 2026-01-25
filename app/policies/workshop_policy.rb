# frozen_string_literal: true

class WorkshopPolicy < ApplicationPolicy
  # destroy = admin only
  # edit = admin or owner
  # scope published vs all

  def index?
    authenticated?
  end

  def show?
    authenticated?
  end

  def create?
    authenticated?
  end

  def update?
    admin? || owner?
  end

  def destroy?
    admin?
  end

  # Scope for workshop index - admins see all, others see published
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.published
    end
  end

  # Scope for search results
  scope_for :relation, :search do |relation|
    if admin?
      relation.all
    else
      relation.published
    end
  end
end
