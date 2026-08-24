class StaffTaggingPolicy < ApplicationPolicy
  # Staff taggings are internal, admin-only — mirrors StaffTagPolicy.
  def index? = admin?

  def edit?
    record.persisted? && admin?
  end

  def update?
    edit?
  end

  def destroy?
    record.persisted? && admin?
  end

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end
