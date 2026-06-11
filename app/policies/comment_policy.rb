class CommentPolicy < ApplicationPolicy
  alias_rule :index?, :create?, :update?, to: :manage?

  def manage?
    admin?
  end
end
