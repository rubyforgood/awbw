class CommentPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def create?
    admin?
  end
end
