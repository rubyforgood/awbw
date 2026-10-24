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

  def credited_author?
    return false unless user&.person_id
    [ record.try(:author_id), record.try(:co_author_id) ].compact.include?(user.person_id)
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
