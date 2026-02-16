class CommentPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  def create?
    authenticated?
  end
end
