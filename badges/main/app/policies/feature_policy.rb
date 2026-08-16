class FeaturePolicy < ApplicationPolicy
  # Anyone signed in can view; the inherited `manage?` rule keeps create/edit/destroy admin-only.
  def index?
    authenticated?
  end

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
