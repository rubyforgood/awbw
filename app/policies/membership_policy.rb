class MembershipPolicy < ApplicationPolicy
  def manage? = admin? && Membership.enabled?

  def show?
    return false unless Membership.enabled?
    owner? || manage?
  end

  def checkout? = Membership.enabled? && user&.person.present?

  def billing_portal? = Membership.enabled? && owner?

  # Admin-only resource; the index scope returns nothing to non-admins (its
  # manage? rule already redirects them).
  relation_scope do |relation|
    next relation if admin?

    relation.none
  end

  params_filter do |params|
    params.permit(:cost_dollars, :autorenewal_cancelled)
  end

  private

  def owner?
    return false unless authenticated? && record.is_a?(Membership)
    record.person == user&.person
  end
end
