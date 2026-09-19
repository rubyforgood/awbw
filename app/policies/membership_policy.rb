class MembershipPolicy < ApplicationPolicy
  def manage? = admin? && Membership.enabled?

  def show?
    return false unless Membership.enabled?
    owner? || manage?
  end

  def owner?
    return false unless authenticated?
    record.person == user&.person
  end
  # Admin-only resource; the index scope returns nothing to non-admins (its
  # manage? rule already redirects them).
  relation_scope do |relation|
    next relation if admin?

    relation.none
  end

  params_filter do |params|
    next params.permit(:cost_dollars, :autorenewal_cancelled) if admin?

    params.permit(:autorenewal_cancelled)
  end
end
