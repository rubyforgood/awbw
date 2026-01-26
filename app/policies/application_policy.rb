# Base class for application policies
class ApplicationPolicy < ActionPolicy::Base
  # Configure additional authorization contexts here
  # (`user` is added by default).
  #
  #   authorize :account, optional: true
  #
  # Read more about authorization context: https://actionpolicy.evilmartians.io/#/authorization_context
  #
  authorize :user, optional: true, allow_nil: true
  pre_check :verify_authenticated!

  alias_rule :new?, :create?, :edit?, :update?, :destroy?, to: :manage?

  def manage?
    admin?
  end

  def index?
    true
  end

  def show?
    admin? || record.published?
  end


  private
  # Define shared methods useful for most policies.

  def admin?
    user&.super_user?
  end

  def owner?
    record.user_id == user.id
  end

  def authenticated? = user.present?


  def verify_authenticated!
    deny! unless authenticated?
  end
end
