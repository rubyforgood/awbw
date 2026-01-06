class ResourcePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  relation_scope do |relation|
    if admin?
      relation
    else
      relation.published
    end
  end

  def index?
    true
  end

  def filter_published?
    admin?
  end
  #
  # def update?
  #   # here we can access our context and record
  #   user.admin? || (user.id == record.user_id)
  # end
end
