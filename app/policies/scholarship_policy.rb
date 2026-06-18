class ScholarshipPolicy < ApplicationPolicy
  # Scholarships are an admin-only resource; the index scope returns nothing to
  # non-admins (its index? rule already redirects them).
  relation_scope do |relation|
    next relation if admin?

    relation.none
  end

  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
