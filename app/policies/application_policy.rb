class ApplicationPolicy < ActionPolicy::Base
  # Read more about authorization context: https://actionpolicy.evilmartians.io/#/authorization_context

  authorize :user, optional: true, allow_nil: true
  scope_matcher :relation, ActiveRecord::Relation

  default_rule :deny!
  # alias_rule :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, to: :manage? ## this is causing inheritance issues with StoryIdeaPolicy, which has its own index? and show? rules

  def deny!
    false
  end

  private
  # Define shared methods useful for most policies.

  def admin?
    user&.super_user
  end

  def authenticated? = user.present?

  def owner?
    record.respond_to?(:created_by_id) && record.created_by_id == user&.id ||
      record.respond_to?(:user_id) && record.user_id == user&.id
  end
end
