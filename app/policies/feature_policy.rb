class FeaturePolicy < ApplicationPolicy
  # The page is for signed-in users; creating/editing/deleting stays admin-only
  # via the inherited `manage?` default rule.
  def index?
    authenticated?
  end

  # Admin-facing features are visible to super-admins only. Everyone signed in
  # can see published public-/user-facing features.
  def show?
    return false unless authenticated?

    admin? || (record.published? && !record.admin_only?)
  end

  relation_scope do |relation|
    next relation.none unless authenticated?
    next relation if admin?

    relation.published.readable_by_non_admins
  end
end
