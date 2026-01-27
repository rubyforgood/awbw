class DashboardPolicy < ApplicationPolicy
  skip_pre_check :verify_authenticated!

  def index?
    true
  end

  relation_scope do |relation|
    if authenticated?
      relation.featured
    else
      relation.visitor_featured
    end
  end
end
