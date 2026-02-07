class BannerPolicy < ApplicationPolicy
  # We default to the `manage?` rule, so we only need to define rules that differ from it.
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  # def index?
  #   true
  # end

  def show?
    admin? || record.published?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping
  #

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end
