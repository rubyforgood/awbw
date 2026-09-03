class TopicSubscriptionPolicy < ApplicationPolicy
  def index?
    admin?
  end

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end
