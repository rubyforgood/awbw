class ApplicationPolicy < ActionPolicy::Base
  # Read more about authorization context: https://actionpolicy.evilmartians.io/#/authorization_context

  authorize :user, optional: true, allow_nil: true

  default_rule :manage?
  alias_rule :index?, :show?, :new?, :create?, :edit?, :update?, to: :manage?

  def manage?
    admin?
  end

  def destroy?
    record.persisted? && manage?
  end

  private
  # Define shared methods useful for most policies.

  def admin?
    user&.super_user?
  end

  def authenticated? = user.present?

  # Staging toggle for the not-yet-launched public-profiles experience: opens
  # people/organizations to signed-in users and lets a person edit their own
  # profile. Off unless PROFILES_ENABLED is set, so production stays unchanged.
  def profiles_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV["PROFILES_ENABLED"])
  end

  def owner?
    return false unless user
    if record.respond_to?(:created_by_id)
      record.created_by_id == user.id
    elsif record.respond_to?(:user_id)
      record.user_id == user.id
    else
      false
    end
  end
end
