class CommentPolicy < ApplicationPolicy
  alias_rule :index?, :create?, to: :manage?

  def manage?
    admin?
  end
end
