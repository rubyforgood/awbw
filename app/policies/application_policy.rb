# frozen_string_literal: true

class ApplicationPolicy < ActionPolicy::Base
  # Common authorization predicates

  def authenticated?
    user.present?
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

  def index?
    authenticated?
  end

  def show?
    authenticated?
  end

  def new?
    create?
  end

  def create?
    authenticated?
  end

  def edit?
    update?
  end

  def update?
    authenticated?
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
