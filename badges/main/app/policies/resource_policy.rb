class ResourcePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  def download?
    true
  end

  def filter_published?
    admin?
  end

  relation_scope do |relation|
    if admin?
      relation
    else
      relation.published
    end
  end
end
