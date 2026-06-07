class GrantPolicy < ApplicationPolicy
  # Grants are an admin-only resource; all default rules resolve to manage? (admin?).

  relation_scope do |relation|
    next relation if admin?

    relation.none
  end
end
