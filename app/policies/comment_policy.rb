class CommentPolicy < ApplicationPolicy
  alias_rule :index?, :create?, :update?, :destroy?, to: :manage?

  def manage?
    admin?
  end
end
