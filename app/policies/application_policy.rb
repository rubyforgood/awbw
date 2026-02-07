class ApplicationPolicy < ActionPolicy::Base
  # Read more about authorization context: https://actionpolicy.evilmartians.io/#/authorization_context

  authorize :user, optional: true, allow_nil: true

  default_rule :manage?
  alias_rule :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, to: :manage?

  def manage?
    admin?
  end

  private
  # Define shared methods useful for most policies.

  def admin?
    user&.super_user?
  end

  def authenticated? = user.present?

  def owner?
    record.respond_to?(:created_by_id) && record.created_by_id == user&.id ||
      record.respond_to?(:user_id) && record.user_id == user&.id
  end
end
