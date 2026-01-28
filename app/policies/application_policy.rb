# frozen_string_literal: true

class ApplicationPolicy < ActionPolicy::Base
  # Require authentication for all policy checks
  pre_check :authenticated?

  # Common authorization predicates

  def authenticated?
    user.present? || deny!
  end

  def admin?
    user&.super_user?
  end

  def owner?
    return false unless record.respond_to?(:user_id) || record.respond_to?(:created_by_id)

    owner_id = record.try(:user_id) || record.try(:created_by_id)
    owner_id == user&.id
  end

  def project_member?
    return false unless record.respond_to?(:project_id) && record.project_id.present?

    user&.project_ids&.include?(record.project_id)
  end

  # Default CRUD rules - override in specific policies as needed
  # Note: pre_check :authenticated? ensures user is logged in before these run

  def index?
    true
  end

  def show?
    true
  end

  def new?
    create?
  end

  def create?
    true
  end

  def edit?
    update?
  end

  def update?
    true
  end

  def destroy?
    admin?
  end

  # Default scope - admin sees all, others see published only
  scope_for :relation do |relation|
    if admin?
      relation.all
    elsif relation.respond_to?(:published)
      relation.published
    elsif relation.respond_to?(:active)
      relation.active
    else
      relation.all
    end
  end
end
