class HomePolicy < ApplicationPolicy
  def index?
    true
  end

  relation_scope do |relation|
    if authenticated?
      relation.featured
    else
      relation.publicly_featured
    end
  end
end
