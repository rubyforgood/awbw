class TopicSubscriptionPolicy < ApplicationPolicy
  def index?
    admin?
  end
end
